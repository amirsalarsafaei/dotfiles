{
  config,
  lib,
  pkgs,
  ...
}:

# Local coding LLM for Claude Code (g14 only).
#
# Serves Qwen3.6-35B-A3B-APEX (an MoE: 35B total / 3B active, 256 experts,
# 40 layers, 256k native context) through llama-swap on a CUDA llama.cpp,
# and bridges it to Claude Code via claude-code-router (see
# home/modules/programs/development/claude-code.nix, the `local-claude`
# wrapper).
#
# Hardware: RTX 5080 Mobile (16 GB VRAM, Blackwell sm_120) + Ryzen AI 9
# HX 370 (12c/24t) + 32 GB RAM. The model does not fit in VRAM, so we use
# the MoE-aware split: ALL attention + shared experts + KV cache stay on the
# GPU (`-ngl 999`), and only the routed-expert FFN tensors of the first
# `--n-cpu-moe` layers spill to CPU. With A3B (3B active params) the CPU
# expert path is cheap, so we get near-GPU latency while fitting 128k ctx.
#
# Concurrency is 2 (`-np 2`) so Claude Code's main request and its separate
# safety-classifier / background (`nothink`) request can be served at the same
# time — with one slot the second request gets "model temporarily unavailable".
# `--kv-unified` makes --ctx-size a single shared KV pool instead of splitting
# it evenly per slot, so the main request can still use ~the full 128k (and
# VRAM is unchanged, since the total buffer size is the same).

let
  # CUDA-enabled llama.cpp. The nixpkgs `llama-cpp` in this flake is built
  # CPU-only; re-import the *same* pinned nixpkgs with CUDA on, pinned to the
  # 5080's compute capability (sm_120) so kernels are precompiled natively —
  # no runtime PTX JIT, which would otherwise trip the service sandbox's
  # MemoryDenyWriteExecute=true. cudaPackages here is 12.9, which lists 12.0.
  llamaCppCuda =
    (import pkgs.path {
      system = pkgs.stdenv.hostPlatform.system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
        cudaCapabilities = [ "12.0" ];
      };
    }).llama-cpp;

  llamaServer = lib.getExe' llamaCppCuda "llama-server";
  llamaServerCurrent = pkgs.writeShellApplication {
    name = "llama-server-current";
    runtimeInputs = [ llamaCppCuda ];
    text = ''
      port="''${1:?missing llama-swap port}"
      exec ${llamaServer} \
        --host 127.0.0.1 --port "$port" \
        -m ${currentModelPath} \
        --alias qwen3.6-apex \
        -ngl 999 \
        --n-cpu-moe "''${LLM_N_CPU_MOE:-6}" \
        -fa on \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --ctx-size "''${LLM_CTX_SIZE:-131072}" \
        --parallel "''${LLM_PARALLEL:-2}" --kv-unified \
        --threads "''${LLM_THREADS:-12}" --threads-batch "''${LLM_THREADS_BATCH:-12}" \
        --numa isolate \
        --cache-ram 4096 \
        --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0 \
        --jinja \
        --no-webui \
        --metrics
    '';
  };

  # The GGUF is too large (~17 GB) to be nix-managed; it lives outside /home
  # because the llama-swap unit sets ProtectHome=true. Place it with:
  #   sudo install -d -m0755 /var/lib/llama-models
  #   sudo mv ~/Downloads/Qwen3.6-35B-A3B-APEX-I-Compact.gguf /var/lib/llama-models/
  modelDir = "/var/lib/llama-models";
  defaultModel = "Qwen3.6-35B-A3B-APEX-I-Compact.gguf";
  currentModelPath = "${modelDir}/current.gguf";
  currentModelEnv = "${modelDir}/current.env";

  localLlmSwitch = pkgs.writeShellApplication {
    name = "llm-switch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      usage() {
        cat <<USAGE
      Usage: llm-switch <model.gguf|/path/to/model.gguf>

      Switch llama-swap to a GGUF already in ${modelDir}.
      Use llm-import ~/Downloads/model.gguf first for files under /home.
      USAGE
      }

      if [ "$#" -ne 1 ]; then
        usage >&2
        exit 2
      fi

      input="$1"
      case "''${input,,}" in
        compact | default | fast)
          input="${defaultModel}"
          ;;
        quality)
          input="Qwen3.6-35B-A3B-APEX-I-Quality.gguf"
          ;;
      esac

      case "$input" in
        */*) model_path="$input" ;;
        *) model_path="${modelDir}/$input" ;;
      esac

      if [ ! -f "$model_path" ]; then
        echo "Model not found: $model_path" >&2
        exit 1
      fi

      model_path="$(readlink -f "$model_path")"
      case "$model_path" in
        ${modelDir}/*.gguf) ;;
        *)
          echo "Model must be a .gguf under ${modelDir}: $model_path" >&2
          exit 1
          ;;
      esac

      case "$(basename "$model_path")" in
        *Quality*)
          n_cpu_moe=16
          ctx_size=131072
          parallel=2
          threads=12
          threads_batch=12
          ;;
        *)
          n_cpu_moe=6
          ctx_size=131072
          parallel=2
          threads=8
          threads_batch=8
          ;;
      esac

      ln -sfn "$model_path" "${currentModelPath}"
      {
        printf 'LLM_N_CPU_MOE=%s\n' "$n_cpu_moe"
        printf 'LLM_CTX_SIZE=%s\n' "$ctx_size"
        printf 'LLM_PARALLEL=%s\n' "$parallel"
        printf 'LLM_THREADS=%s\n' "$threads"
        printf 'LLM_THREADS_BATCH=%s\n' "$threads_batch"
      } > "${currentModelEnv}"
      systemctl restart llama-swap.service
      echo "llama-swap now uses: $(basename "$model_path") (n-cpu-moe=$n_cpu_moe, ctx=$ctx_size, parallel=$parallel)"
    '';
  };

  localLlmImport = pkgs.writeShellApplication {
    name = "llm-import";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      usage() {
        cat <<USAGE
      Usage: llm-import <path/to/model.gguf> [stored-name.gguf]

      Copies a GGUF into ${modelDir}, points current.gguf at it, and restarts llama-swap.
      USAGE
      }

      if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        usage >&2
        exit 2
      fi

      source_path="$1"
      if [ ! -f "$source_path" ]; then
        echo "Model not found: $source_path" >&2
        exit 1
      fi

      name="''${2:-$(basename "$source_path")}"
      case "$name" in
        *.gguf) ;;
        *)
          echo "Stored name must end in .gguf: $name" >&2
          exit 1
          ;;
      esac

      case "$name" in
        *Quality*)
          n_cpu_moe=16
          ctx_size=131072
          parallel=2
          threads=12
          threads_batch=12
          ;;
        *)
          n_cpu_moe=6
          ctx_size=131072
          parallel=2
          threads=8
          threads_batch=8
          ;;
      esac

      install -D -m0644 "$source_path" "${modelDir}/$name"
      ln -sfn "${modelDir}/$name" "${currentModelPath}"
      {
        printf 'LLM_N_CPU_MOE=%s\n' "$n_cpu_moe"
        printf 'LLM_CTX_SIZE=%s\n' "$ctx_size"
        printf 'LLM_PARALLEL=%s\n' "$parallel"
        printf 'LLM_THREADS=%s\n' "$threads"
        printf 'LLM_THREADS_BATCH=%s\n' "$threads_batch"
      } > "${currentModelEnv}"
      systemctl restart llama-swap.service
      echo "Imported and selected: $name (n-cpu-moe=$n_cpu_moe, ctx=$ctx_size, parallel=$parallel)"
    '';
  };

  localLlmList = pkgs.writeShellApplication {
    name = "llm-list";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      current=""
      if [ -e "${currentModelPath}" ]; then
        current="$(readlink -f "${currentModelPath}")"
      fi

      for model_path in ${modelDir}/*.gguf; do
        [ -e "$model_path" ] || continue
        marker=" "
        if [ "$(readlink -f "$model_path")" = "$current" ]; then
          marker="*"
        fi
        printf "%s %s\\n" "$marker" "$(basename "$model_path")"
      done
    '';
  };

  localLlmStatus = pkgs.writeShellApplication {
    name = "llm-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      if [ -e "${currentModelPath}" ]; then
        printf 'model: %s\n' "$(basename "$(readlink -f "${currentModelPath}")")"
      else
        printf 'model: missing\n'
      fi

      if [ -s "${currentModelEnv}" ]; then
        cat "${currentModelEnv}"
      else
        printf 'profile: defaults\n'
      fi

      printf 'service: %s\n' "$(systemctl is-active llama-swap.service || true)"

      status_file="$(mktemp)"
      if curl -fsS http://127.0.0.1:18080/v1/models > "$status_file" 2>/dev/null; then
        jq -r '.data[]?.id | "api_model: " + .' "$status_file"
      else
        printf 'api: unavailable\n'
      fi
      rm -f "$status_file"
    '';
  };

  localLlmCurl = pkgs.writeShellApplication {
    name = "llm-curl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      model="qwen3.6-apex"
      max_tokens=512
      temperature=0.2
      system_prompt="You are a concise local coding assistant."
      raw=false
      no_think=false

      usage() {
        cat <<USAGE
      Usage: llm-curl [--model MODEL] [--max-tokens N] [--temp N] [--system TEXT] [--no-think] [--raw] [prompt...]

      Sends one OpenAI-compatible chat completion request to http://127.0.0.1:18080/v1.
      If no prompt is provided as arguments, stdin is used.
      USAGE
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --model)
            model="''${2:?missing value for --model}"
            shift 2
            ;;
          --max-tokens)
            max_tokens="''${2:?missing value for --max-tokens}"
            shift 2
            ;;
          --temp | --temperature)
            temperature="''${2:?missing value for --temp}"
            shift 2
            ;;
          --system)
            system_prompt="''${2:?missing value for --system}"
            shift 2
            ;;
          --no-think | --nothink)
            no_think=true
            shift
            ;;
          --raw)
            raw=true
            shift
            ;;
          -h | --help)
            usage
            exit 0
            ;;
          --)
            shift
            break
            ;;
          -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      if [ "$#" -gt 0 ]; then
        prompt="$*"
      else
        prompt="$(cat)"
      fi

      if [ -z "$prompt" ]; then
        echo "Prompt is empty" >&2
        exit 2
      fi

      jq_args=(
        --arg model "$model"
        --arg system_prompt "$system_prompt"
        --arg prompt "$prompt"
        --argjson max_tokens "$max_tokens"
        --argjson temperature "$temperature"
      )
      jq_filter="$(cat <<'JQ'
      {
        model: $model,
        temperature: $temperature,
        max_tokens: $max_tokens,
        messages: [
          { role: "system", content: $system_prompt },
          { role: "user", content: $prompt }
        ]
      }
      JQ
      )"

      if [ "$no_think" = true ]; then
        jq_filter="$jq_filter + { chat_template_kwargs: { enable_thinking: false } }"
      fi

      response="$(
        jq -n "''${jq_args[@]}" "$jq_filter" \
          | curl -fsS http://127.0.0.1:18080/v1/chat/completions \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer sk-local' \
              --data-binary @-
      )"

      if [ "$raw" = true ]; then
        printf '%s\n' "$response"
      else
        printf '%s\n' "$response" | jq -r '.choices[0].message.content'
      fi
    '';
  };

  localLlmBench = pkgs.writeShellApplication {
    name = "llm-bench-current";
    runtimeInputs = [
      llamaCppCuda
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      if [ ! -e "${currentModelPath}" ]; then
        echo "No selected model. Run: sudo llm-import ~/Downloads/model.gguf" >&2
        exit 1
      fi

      read_env() {
        key="$1"
        default="$2"
        value=""
        if [ -r "${currentModelEnv}" ]; then
          value="$(grep -E "^$key=" "${currentModelEnv}" | tail -n 1 | cut -d= -f2- || true)"
        fi
        printf '%s\n' "''${value:-$default}"
      }

      exec ${lib.getExe' llamaCppCuda "llama-bench"} \
        -m "${currentModelPath}" \
        -ngl 999 \
        --n-cpu-moe "$(read_env LLM_N_CPU_MOE 6)" \
        -fa 1 \
        -ctk q8_0 -ctv q8_0 \
        -c "$(read_env LLM_CTX_SIZE 131072)" \
        -t "$(read_env LLM_THREADS 8)" \
        -p 512 \
        -n 128 \
        -r 3 \
        "$@"
    '';
  };

  localLlmQualityBench = pkgs.writeShellApplication {
    name = "llm-quality-bench";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      out_dir="''${1:-$HOME/.local/share/llm-quality-bench/$(date +%Y%m%d-%H%M%S)}"
      mkdir -p "$out_dir"

      model="$(curl -fsS http://127.0.0.1:18080/v1/models | jq -r '.data[0].id // "qwen3.6-apex"')"

      run_prompt() {
        name="$1"
        prompt="$2"
        jq -n \
          --arg model "$model" \
          --arg prompt "$prompt" \
          '{
            model: $model,
            temperature: 0.2,
            top_p: 0.8,
            max_tokens: 1600,
            messages: [
              {
                role: "system",
                content: "You are a careful coding assistant. Be concise, correct, and explain important tradeoffs."
              },
              {
                role: "user",
                content: $prompt
              }
            ]
          }' \
          | curl -fsS http://127.0.0.1:18080/v1/chat/completions \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer sk-local' \
              --data-binary @- \
          | tee "$out_dir/$name.json" \
          | jq -r '.choices[0].message.content' > "$out_dir/$name.md"
      }

      run_prompt "01_debugging" "Find the bug in this Go code, explain why it happens, and provide a corrected version:\n\npackage main\n\nimport \"fmt\"\n\nfunc main() {\n\titems := []string{\"a\", \"b\", \"c\"}\n\tptrs := []*string{}\n\tfor _, item := range items {\n\t\tptrs = append(ptrs, &item)\n\t}\n\tfor _, ptr := range ptrs {\n\t\tfmt.Println(*ptr)\n\t}\n}"
      run_prompt "02_repo_change" "Design a minimal implementation plan for adding a NixOS helper command that switches a root-owned GGUF symlink and restarts a systemd service. Include edge cases and validation steps."
      run_prompt "03_tool_calling" "You need to edit a dotfiles repo safely. The user asks: 'make Hyprland float all Steam popups'. Ask at most one clarifying question only if necessary, then give the exact kind of file/search steps you would perform."
      run_prompt "04_reasoning" "A local llama.cpp server has 16 GB VRAM, 32 GB RAM, a 35B MoE GGUF, 128k context, q8 KV, and --parallel 2. Explain how you would tune GPU layer offload, CPU MoE layers, and context size without causing CUDA OOM."

      {
        echo "# LLM quality bench"
        echo
        echo "Model: $model"
        echo "Output: $out_dir"
        echo
        for file in "$out_dir"/*.md; do
          echo "## $(basename "$file" .md)"
          echo
          cat "$file"
          echo
        done
      } > "$out_dir/summary.md"

      echo "$out_dir/summary.md"
    '';
  };
in
{
  # Ensure the models dir exists; the GGUF itself is dropped in manually.
  systemd.tmpfiles.rules = [
    "d ${modelDir} 0755 root root - -"
    "L ${currentModelPath} - - - - ${modelDir}/${defaultModel}"
    "f ${currentModelEnv} 0644 root root - -"
  ];

  environment.systemPackages = [
    localLlmImport
    localLlmSwitch
    localLlmList
    localLlmStatus
    localLlmCurl
    localLlmBench
    localLlmQualityBench
  ];

  services.llama-swap = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 18080;
    openFirewall = false;
    package = pkgs.llama-swap;
    settings = {
      # Cold start loads the weights + copies tensors to VRAM; give it room.
      healthCheckTimeout = 600;
      logLevel = "info";

      models."qwen3.6-apex" = {
        # llama-swap substitutes ${PORT}; it joins this multi-line command on
        # whitespace. --n-cpu-moe is the one value to tune: lower = more experts
        # on GPU = faster, until VRAM (weights + 128k KV cache) is exhausted.
        # --n-cpu-moe is the offload split: lower = more experts on GPU =
        # faster. Benchmarked (warmup + 4-rep mean) on this 5080 (16 GB) at
        # -c 131072, q8 KV:
        #   n=12 -> 2.2 GB free,  36.7 tok/s gen
        #   n=10 -> 1.55 GB free, 36.5 tok/s gen
        #   n=8  -> 0.9 GB free,  48.5 tok/s gen
        #   n=6  -> 0.24 GB free, 55.9 tok/s gen   <- chosen (fastest)
        # n=6 is the floor: ~0.33 GB/expert-layer, so n=5 would OOM at 128k
        # (this model has only 2 KV heads, so the cache is tiny and the VRAM is
        # dominated by expert WEIGHTS — shrinking ctx/KV won't free a layer).
        # The 0.24 GB margin is thin: if the dGPU is ALSO driving the desktop
        # (prime sync) or you hit a CUDA OOM, raise --n-cpu-moe to 7-8.
        cmd = ''
          ${lib.getExe llamaServerCurrent} ''${PORT}
        '';
        aliases = [
          "claude-local"
          "qwen3.6-apex-compact"
          # ccr's small/fast (background) route targets this name; it resolves
          # to THIS same loaded process (no second model in VRAM). ccr's
          # `reasoning` transformer disables thinking on those requests.
          "qwen3.6-apex-nothink"
        ];
        proxy = "http://127.0.0.1:\${PORT}";
        timeouts = {
          connect = 60;
          keepalive = 0;
          responseHeader = 0;
          tlsHandshake = 10;
          idleConn = 0;
        };
        # Unload after 30 min idle to free 16 GB VRAM on the laptop; a cold
        # reload is ~15 s. Set to 0 to keep it resident.
        ttl = 1800;
      };
    };
  };

  # llama-swap's upstream unit is heavily hardened. Two relaxations are needed
  # for the CUDA server (ollama's nixos module makes the same concessions):
  #   - ProcSubset "all": llama.cpp/ggml reads /proc/meminfo for RAM detection;
  #     the default "pid" hides it.
  # GPU device nodes are already reachable via PrivateDevices=false, and we
  # keep MemoryDenyWriteExecute=true (ollama-cuda runs fine with it because,
  # like us, it ships precompiled kernels — hence the sm_120 pin above).
  systemd.services.llama-swap = {
    serviceConfig = {
      ProcSubset = lib.mkForce "all";
      EnvironmentFile = currentModelEnv;
    };
    environment = {
      # We build native sm_120 cubins, so there is no JIT cache to write
      # (and ProtectHome would block ~/.nv anyway).
      CUDA_CACHE_DISABLE = "1";
    };
  };
}
