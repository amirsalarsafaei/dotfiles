{
  config,
  lib,
  pkgs,
  ...
}:

# Local coding LLM for Claude Code (g14 only).
#
# Serves Qwen3.6-35B-A3B-APEX (MoE: 35B total / 3B active, 256 experts,
# 40 layers, 256k native context) through llama-swap on a CUDA llama.cpp,
# bridged to Claude Code via LiteLLM (see
# home/modules/programs/development/claude-code.nix, `local-claude`).
#
# Hardware: RTX 5080 Mobile (16 GB VRAM, sm_120) + Ryzen AI 9 HX 370 + 32 GB
# RAM. MoE-aware split: ALL attention + shared experts + KV cache on GPU
# (`-ngl 999`); only routed-expert FFN tensors of the first `--n-cpu-moe`
# layers spill to CPU. Concurrency is 2 (`-np 2`) so Claude Code's main and
# safety-classifier/background requests are served simultaneously;
# `--kv-unified` shares --ctx-size as one KV pool across slots.

let
  # ---------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------
  port = 18080;
  litellmPort = 18081;
  apiBase = "http://127.0.0.1:${toString port}";
  localModel = "qwen3.6-apex";
  localModelFast = "qwen3.6-apex-nothink";
  localProxyKey = "sk-local";

  # Timeout configuration for local LLM with hardware constraints
  requestTimeout = 600; # 10min - standard timeout for local processing
  longRequestTimeout = 1800; # 30min - extended timeout for complex/long-context requests
  healthCheckTimeout = 600; # 10min - cold start loads weights + copies tensors to VRAM

  # GGUF too large (~17 GB) to be nix-managed; lives outside /home because
  # the llama-swap unit sets ProtectHome=true. Bootstrap with:
  #   sudo install -d -m0755 /var/lib/llama-models
  #   sudo mv ~/Downloads/Qwen3.6-35B-A3B-APEX-I-Compact.gguf /var/lib/llama-models/
  modelDir = "/var/lib/llama-models";
  defaultModel = "Qwen3.6-35B-A3B-APEX-I-Compact.gguf";
  qwen27bDownload = "/home/amirsalar/Downloads/Qwen3.6-27B-UD-Q4_K_XL.gguf";
  currentModelPath = "${modelDir}/current.gguf";
  currentModelEnv = "${modelDir}/current.env";

  # Default profile settings (overridden by per-model rules)
  defaultProfile = {
    gpuLayers = 999;
    nCpuMoe = 7;
    threads = 8;
    threadsBatch = 12;
    ubatch = 1024;
    ctxSize = 131072;
    parallel = 1;
    batch = 2048;
    cacheTypeK = "q8_0";
    cacheTypeV = "q8_0";
  };

  # Per-model tuning, ordered (first glob match wins)
  profileRules = [
    {
      pattern = "Qwen3.6-27B-*";
      gpuLayers = 999;
      nCpuMoe = 16;
      threads = 12;
      ubatch = 512;
      ctx_size = 65536;
    }
    {
      pattern = "Laguna-XS-*";
      nCpuMoe = 12;
      threads = 12;
      ubatch = 512;
    }
    {
      pattern = "*UD*";
      nCpuMoe = 16;
      threads = 12;
      ubatch = 512;
    }
    {
      pattern = "*Quality*";
      nCpuMoe = 16;
      threads = 12;
      ubatch = 512;
      ctx_size = 150000;
    }
    {
      pattern = "*";
      inherit (defaultProfile) nCpuMoe threads ubatch;
    }
  ];

  modelAliases = {
    compact = defaultModel;
    default = defaultModel;
    fast = defaultModel;
    quality = "Qwen3.6-35B-A3B-APEX-I-Quality.gguf";
    ud = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
    "27b" = "Qwen3.6-27B-UD-Q4_K_XL.gguf";
    qwen27b = "Qwen3.6-27B-UD-Q4_K_XL.gguf";
    "qwen3.6-27b" = "Qwen3.6-27B-UD-Q4_K_XL.gguf";
    laguna = "Laguna-XS-2.1-Q4_K_M.gguf";
    laguna-xs = "Laguna-XS-2.1-Q4_K_M.gguf";
  };

  benchModelAliases = modelAliases // {
    "27b" = qwen27bDownload;
    qwen27b = qwen27bDownload;
    "qwen3.6-27b" = qwen27bDownload;
    qwen27b-download = qwen27bDownload;
  };

  # ---------------------------------------------------------------------
  # CUDA llama.cpp
  # ---------------------------------------------------------------------
  # nixpkgs `llama-cpp` in this flake is CPU-only; re-import the same pinned
  # nixpkgs with CUDA on, pinned to sm_120 so kernels are precompiled —
  # no runtime PTX JIT, which would trip MemoryDenyWriteExecute=true.
  llamaCppCuda =
    (import pkgs.path {
      system = pkgs.stdenv.hostPlatform.system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
        cudaCapabilities = [ "12.0" ];
      };
    }).llama-cpp;

  llamaServerCurrent = pkgs.writeShellApplication {
    name = "llama-server-current";
    runtimeInputs = [ llamaCppCuda ];
    text = ''
      port="''${1:?missing llama-swap port}"
      exec llama-server \
        --host 127.0.0.1 --port "$port" \
        -m ${currentModelPath} \
        --alias ${localModel} \
        --n-cpu-moe "''${LLM_N_CPU_MOE:-${toString defaultProfile.nCpuMoe}}" \
        -fa on \
        --cache-type-k "''${LLM_CACHE_TYPE_K:-${defaultProfile.cacheTypeK}}" \
        --cache-type-v "''${LLM_CACHE_TYPE_V:-${defaultProfile.cacheTypeV}}" \
        --ctx-size "''${LLM_CTX_SIZE:-${toString defaultProfile.ctxSize}}" \
        --parallel "''${LLM_PARALLEL:-${toString defaultProfile.parallel}}" --kv-unified \
        --batch-size "''${LLM_BATCH:-${toString defaultProfile.batch}}" \
        --ubatch-size "''${LLM_UBATCH:-${toString defaultProfile.ubatch}}" \
        --threads "''${LLM_THREADS:-${toString defaultProfile.threads}}" \
        --threads-batch "''${LLM_THREADS_BATCH:-${toString defaultProfile.threadsBatch}}" \
        --timeout "''${LLM_REQUEST_TIMEOUT:-${toString longRequestTimeout}}" \
        --cache-reuse 256 \
        --cache-ram 8192 \
        --mlock \
        --temp 0.3 --top-p 0.9 --top-k 40 --min-p 0.05 \
        --jinja --reasoning-preserve --no-webui --metrics
    '';
  };

  # ---------------------------------------------------------------------
  # Shared shell library (profile selection + activation)
  # ---------------------------------------------------------------------
  profileCase = lib.concatMapStringsSep "\n        " (
    r:
    let
      gpuLayers = r.gpuLayers or defaultProfile.gpuLayers;
      ctxSize = r.ctx_size or defaultProfile.ctxSize;
      cacheTypeK = r.cacheTypeK or defaultProfile.cacheTypeK;
      cacheTypeV = r.cacheTypeV or defaultProfile.cacheTypeV;
    in
    "${r.pattern}) gpu_layers=${toString gpuLayers} n_cpu_moe=${toString r.nCpuMoe} threads=${toString r.threads} ubatch=${toString r.ubatch} ctx_size=${toString ctxSize} cache_type_k=${cacheTypeK} cache_type_v=${cacheTypeV};;"
  ) profileRules;

  aliasCase = lib.concatStringsSep "\n        " (
    lib.mapAttrsToList (name: target: ''${name}) input="${target}" ;;'') modelAliases
  );

  benchAliasCase = lib.concatStringsSep "\n        " (
    lib.mapAttrsToList (name: target: ''${name}) input="${target}" ;;'') benchModelAliases
  );

  llmShellLib = ''
    select_profile() {
      parallel=${toString defaultProfile.parallel}
      threads_batch=${toString defaultProfile.threadsBatch}
      batch=${toString defaultProfile.batch}
      ctx_size=${toString defaultProfile.ctxSize}
      gpu_layers=${toString defaultProfile.gpuLayers}
      cache_type_k=${defaultProfile.cacheTypeK}
      cache_type_v=${defaultProfile.cacheTypeV}
      case "$1" in
        ${profileCase}
      esac
    }

    activate_model() {
      local model_path="$1" verb="$2" name
      name="$(basename "$model_path")"
      select_profile "$name"
      ln -sfn "$model_path" "${currentModelPath}"
      cat > "${currentModelEnv}" <<EOF
    LLM_GPU_LAYERS=$gpu_layers
    LLM_N_CPU_MOE=$n_cpu_moe
    LLM_CTX_SIZE=$ctx_size
    LLM_PARALLEL=$parallel
    LLM_THREADS=$threads
    LLM_THREADS_BATCH=$threads_batch
    LLM_BATCH=$batch
    LLM_UBATCH=$ubatch
    LLM_CACHE_TYPE_K=$cache_type_k
    LLM_CACHE_TYPE_V=$cache_type_v
    EOF
      systemctl restart llama-swap.service
      echo "$verb: $name (ngl=$gpu_layers, n-cpu-moe=$n_cpu_moe, ctx=$ctx_size, parallel=$parallel, ubatch=$ubatch, cache=$cache_type_k/$cache_type_v)"
    }
  '';

  mkTool =
    name: extraInputs: text:
    pkgs.writeShellApplication {
      inherit name text;
      runtimeInputs = [ pkgs.coreutils ] ++ extraInputs;
    };

  # ---------------------------------------------------------------------
  # Tools
  # ---------------------------------------------------------------------
  tools = {
    llm-switch = mkTool "llm-switch" [ pkgs.systemd ] ''
      ${llmShellLib}
      if [ "$#" -ne 1 ]; then
        cat >&2 <<USAGE
      Usage: llm-switch <alias|model.gguf|/path/to/model.gguf>

      Switch llama-swap to a GGUF already in ${modelDir}.
      Use llm-import ~/Downloads/model.gguf first for files under /home.
      USAGE
        exit 2
      fi

      input="$1"
      case "''${input,,}" in
        ${aliasCase}
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

      activate_model "$model_path" "llama-swap now uses"
    '';

    llm-import = mkTool "llm-import" [ pkgs.systemd ] ''
      ${llmShellLib}
      if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        cat >&2 <<USAGE
      Usage: llm-import <path/to/model.gguf> [stored-name.gguf]

      Copies a GGUF into ${modelDir}, points current.gguf at it, and restarts llama-swap.
      USAGE
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

      install -D -m0644 "$source_path" "${modelDir}/$name"
      activate_model "${modelDir}/$name" "Imported and selected"
    '';

    llm-list = mkTool "llm-list" [ ] ''
      current=""
      [ -e "${currentModelPath}" ] && current="$(readlink -f "${currentModelPath}")"
      for model_path in ${modelDir}/*.gguf; do
        [ -e "$model_path" ] || continue
        marker=" "
        [ "$(readlink -f "$model_path")" = "$current" ] && marker="*"
        printf '%s %s\n' "$marker" "$(basename "$model_path")"
      done
    '';

    llm-status = mkTool "llm-status" [ pkgs.curl pkgs.jq pkgs.systemd ] ''
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

      if models_json="$(curl -fsS ${apiBase}/v1/models 2>/dev/null)"; then
        jq -r '.data[]?.id | "api_model: " + .' <<< "$models_json"
      else
        printf 'api: unavailable\n'
      fi
    '';

    llm-curl = mkTool "llm-curl" [ pkgs.curl pkgs.jq ] ''
      model="${localModel}"
      max_tokens=512
      temperature=0.2
      system_prompt="You are a concise local coding assistant."
      raw=false
      no_think=false

      usage() {
        cat <<USAGE
      Usage: llm-curl [--model MODEL] [--max-tokens N] [--temp N] [--system TEXT] [--no-think] [--raw] [prompt...]

      Sends one OpenAI-compatible chat completion request to ${apiBase}/v1.
      If no prompt is provided as arguments, stdin is used.
      USAGE
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --model)      model="''${2:?missing value for --model}"; shift 2 ;;
          --max-tokens) max_tokens="''${2:?missing value for --max-tokens}"; shift 2 ;;
          --temp | --temperature)
                        temperature="''${2:?missing value for --temp}"; shift 2 ;;
          --system)     system_prompt="''${2:?missing value for --system}"; shift 2 ;;
          --no-think | --nothink) no_think=true; shift ;;
          --raw)        raw=true; shift ;;
          -h | --help)  usage; exit 0 ;;
          --)           shift; break ;;
          -*)           echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
          *)            break ;;
        esac
      done

      if [ "$#" -gt 0 ]; then prompt="$*"; else prompt="$(cat)"; fi
      if [ -z "$prompt" ]; then
        echo "Prompt is empty" >&2
        exit 2
      fi

      response="$(
        jq -n \
          --arg model "$model" \
          --arg system_prompt "$system_prompt" \
          --arg prompt "$prompt" \
          --argjson max_tokens "$max_tokens" \
          --argjson temperature "$temperature" \
          --argjson no_think "$no_think" \
          '{
            model: $model,
            temperature: $temperature,
            max_tokens: $max_tokens,
            messages: [
              { role: "system", content: $system_prompt },
              { role: "user", content: $prompt }
            ]
          } + (
            if $no_think then
              { chat_template_kwargs: { enable_thinking: false } }
            else
              {}
            end
          )' \
          | curl -fsS ${apiBase}/v1/chat/completions \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer ${localProxyKey}' \
              --data-binary @-
      )"

      if [ "$raw" = true ]; then
        printf '%s\n' "$response"
      else
        jq -r '.choices[0].message.content' <<< "$response"
      fi
    '';

    llm-bench-current = mkTool "llm-bench-current" [ llamaCppCuda pkgs.gnugrep ] ''
      if [ ! -e "${currentModelPath}" ]; then
        echo "No selected model. Run: sudo llm-import ~/Downloads/model.gguf" >&2
        exit 1
      fi

      read_env() {
        local value=""
        if [ -r "${currentModelEnv}" ]; then
          value="$(grep -E "^$1=" "${currentModelEnv}" | tail -n 1 | cut -d= -f2- || true)"
        fi
        printf '%s\n' "''${value:-$2}"
      }

      exec llama-bench \
        -m "${currentModelPath}" \
        -ngl "$(read_env LLM_GPU_LAYERS ${toString defaultProfile.gpuLayers})" \
        --n-cpu-moe "$(read_env LLM_N_CPU_MOE ${toString defaultProfile.nCpuMoe})" \
        -fa 1 \
        -ctk "$(read_env LLM_CACHE_TYPE_K ${defaultProfile.cacheTypeK})" \
        -ctv "$(read_env LLM_CACHE_TYPE_V ${defaultProfile.cacheTypeV})" \
        -t "$(read_env LLM_THREADS ${toString defaultProfile.threads})" \
        -b "$(read_env LLM_BATCH ${toString defaultProfile.batch})" \
        -ub "$(read_env LLM_UBATCH ${toString defaultProfile.ubatch})" \
        -r 3 \
        "$@"
    '';

    llm-config-bench = mkTool "llm-config-bench" [ llamaCppCuda ] ''
      model_input="''${1:-current}"
      shift || true

      usage() {
        cat <<USAGE
      Usage: llm-config-bench [current|alias|model.gguf|/path/to/model.gguf] [llama-bench args...]

      Benchmarks several llama.cpp configs for one model. Aliases include: compact, quality, ud, 27b, qwen27b-download.
      The 27b aliases point at ${qwen27bDownload}; import it later with: sudo llm-import ${qwen27bDownload}
      USAGE
      }

      case "$model_input" in
        -h | --help)
          usage
          exit 0
          ;;
      esac

      input="$model_input"
      case "''${input,,}" in
        current) input="${currentModelPath}" ;;
        ${benchAliasCase}
      esac

      case "$input" in
        */*) model_path="$input" ;;
        *) model_path="${modelDir}/$input" ;;
      esac

      if [ ! -f "$model_path" ]; then
        echo "Model not found: $model_path" >&2
        exit 1
      fi

      model_name="$(basename "$model_path")"
      select_profile() {
        batch=${toString defaultProfile.batch}
        ctx_size=${toString defaultProfile.ctxSize}
        gpu_layers=${toString defaultProfile.gpuLayers}
        n_cpu_moe=${toString defaultProfile.nCpuMoe}
        threads=${toString defaultProfile.threads}
        ubatch=${toString defaultProfile.ubatch}
        cache_type_k=${defaultProfile.cacheTypeK}
        cache_type_v=${defaultProfile.cacheTypeV}
        case "$1" in
          ${profileCase}
        esac
      }
      select_profile "$model_name"

      candidates=(
        "$gpu_layers:$n_cpu_moe:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:profile"
        "$gpu_layers:$n_cpu_moe:$threads:512:$ctx_size:$cache_type_k:$cache_type_v:ub512"
        "$gpu_layers:$n_cpu_moe:$threads:1024:$ctx_size:$cache_type_k:$cache_type_v:ub1024"
        "$gpu_layers:$n_cpu_moe:$threads:2048:$ctx_size:$cache_type_k:$cache_type_v:ub2048"
        "$gpu_layers:$n_cpu_moe:8:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:t8"
        "$gpu_layers:$n_cpu_moe:12:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:t12"
      )

      case "$model_name" in
        *27B* | *UD*)
          candidates+=(
            "$gpu_layers:20:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe20"
            "$gpu_layers:18:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe18"
            "$gpu_layers:14:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe14"
            "$gpu_layers:12:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe12"
          )
          ;;
        *)
          candidates+=(
            "$gpu_layers:10:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe10"
            "$gpu_layers:8:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe8"
            "$gpu_layers:7:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe7"
            "$gpu_layers:6:$threads:$ubatch:$ctx_size:$cache_type_k:$cache_type_v:moe6"
          )
          ;;
      esac

      seen=":"
      for candidate in "''${candidates[@]}"; do
        IFS=: read -r candidate_ngl candidate_moe candidate_threads candidate_ubatch candidate_ctx candidate_ctk candidate_ctv label <<< "$candidate"
        key="$candidate_ngl:$candidate_moe:$candidate_threads:$candidate_ubatch:$candidate_ctx:$candidate_ctk:$candidate_ctv"
        case "$seen" in
          *":$key:"*) continue ;;
        esac
        seen="$seen$key:"

        printf '\n## %s: ngl=%s n-cpu-moe=%s threads=%s ubatch=%s ctx=%s cache=%s/%s\n' \
          "$label" "$candidate_ngl" "$candidate_moe" "$candidate_threads" "$candidate_ubatch" \
          "$candidate_ctx" "$candidate_ctk" "$candidate_ctv"

        if ! llama-bench \
          -m "$model_path" \
          -ngl "$candidate_ngl" \
          --n-cpu-moe "$candidate_moe" \
          -fa 1 \
          -ctk "$candidate_ctk" -ctv "$candidate_ctv" \
          -c "$candidate_ctx" \
          -t "$candidate_threads" \
          -b "$batch" \
          -ub "$candidate_ubatch" \
          -r 3 \
          "$@"; then
          echo "failed: $label" >&2
        fi
      done
    '';

    llm-quality-bench = mkTool "llm-quality-bench" [ pkgs.curl pkgs.jq ] ''
      out_dir="''${1:-$HOME/.local/share/llm-quality-bench/$(date +%Y%m%d-%H%M%S)}"
      mkdir -p "$out_dir"

      model="$(curl -fsS ${apiBase}/v1/models | jq -r '.data[0].id // "${localModel}"')"

      run_prompt() {
        jq -n --arg model "$model" --arg prompt "$2" '{
          model: $model,
          temperature: 0.2,
          top_p: 0.8,
          max_tokens: 1600,
          messages: [
            { role: "system",
              content: "You are a careful coding assistant. Be concise, correct, and explain important tradeoffs." },
            { role: "user", content: $prompt }
          ]
        }' \
          | curl -fsS ${apiBase}/v1/chat/completions \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer ${localProxyKey}' \
              --data-binary @- \
          | tee "$out_dir/$1.json" \
          | jq -r '.choices[0].message.content' > "$out_dir/$1.md"
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
  systemd.tmpfiles.rules = [
    "d ${modelDir} 0755 root root - -"
    "L ${currentModelPath} - - - - ${modelDir}/${defaultModel}"
    "f ${currentModelEnv} 0644 root root - -"
  ];

  environment.systemPackages = lib.attrValues tools;

  services.llama-swap = {
    enable = true;
    listenAddress = "127.0.0.1";
    inherit port;
    openFirewall = false;
    package = pkgs.llama-swap;
    settings = {
      inherit healthCheckTimeout;
      logLevel = "info";

      models.${localModel} = {
        # --n-cpu-moe is the offload split: lower = more experts on GPU =
        # faster, until VRAM (weights + 128k KV) is exhausted. Benchmarked
        # (warmup + 4-rep mean) on this 5080 (16 GB) at -c 131072, q8 KV:
        #   n=12 -> 2.2 GB free,  36.7 tok/s gen
        #   n=10 -> 1.55 GB free, 36.5 tok/s gen
        #   n=8  -> 0.9
        #   n=7  -> 0.3 GB free, 38.9 tok/s gen (chosen)
        #   n=6  -> OOM
        # Selected n=7 for best speed + VRAM margin. Lower if OOM occurs.
        cmd = "${lib.getExe llamaServerCurrent} \${PORT}";
        aliases = [
          localModelFast
        ];
        proxy = "http://127.0.0.1:\${PORT}";
        timeouts = {
          connect = 60;
          keepalive = 0;
          responseHeader = 0;
          tlsHandshake = 10;
          idleConn = 0;
        };
      };
    };
  };

  services.litellm = {
    enable = true;
    port = litellmPort;
    settings = {
      model_list = [
        {
          model_name = localModel;
          litellm_params = {
            model = "openai/${localModel}";
            api_base = "${apiBase}/v1";
            api_key = localProxyKey;
            extra_body.chat_template_kwargs.enable_thinking = false;
            timeout = longRequestTimeout;
            stream_timeout = longRequestTimeout;
          };
        }
        {
          model_name = localModelFast;
          litellm_params = {
            model = "openai/${localModelFast}";
            api_base = "${apiBase}/v1";
            api_key = localProxyKey;
            extra_body.chat_template_kwargs.enable_thinking = false;
            timeout = requestTimeout;
            stream_timeout = requestTimeout;
          };
        }
      ];

      router_settings = {
        routing_strategy = "simple-shuffle";
        num_retries = 2;
        timeout = longRequestTimeout;
        fallbacks = [ ];
        context_window_fallbacks = [ ];
      };

      litellm_settings = {
        telemetry = false;
        drop_params = true;
        use_chat_completions_url_for_anthropic_messages = true;
        success_callback = [ ];
        failure_callback = [ ];
        request_timeout = longRequestTimeout;
      };

      general_settings = {
        master_key = localProxyKey;
        database_url = null;
        store_model_in_db = false;
      };
    };
  };

  # Systemd unit hardening
  systemd.services.llama-swap = {
    serviceConfig = {
      # Relax ProcSubset to "all" so llama-server can read /proc/self/stat
      # for thread metrics and /proc/meminfo for CUDA memory accounting.
      ProcSubset = lib.mkForce "all";

      # Source per-model environment variables (n-cpu-moe, ctx-size, etc.)
      EnvironmentFile = lib.mkForce [ "-${currentModelEnv}" ];

      # Allow unlimited mlock for pinning model weights in RAM
      LimitMEMLOCK = "infinity";

      # Prioritize compute for responsiveness
      Nice = -5;
      IOSchedulingClass = "realtime";
      IOSchedulingPriority = 0;

      # Prevent CUDA from writing shader cache to $HOME/.nv/ComputeCache
      Environment = [ "CUDA_CACHE_DISABLE=1" ];
    };
  };

  systemd.services.litellm = {
    after = [ "llama-swap.service" ];
    wants = [ "llama-swap.service" ];
  };
}
