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
      inherit (pkgs) system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
        cudaCapabilities = [ "12.0" ];
      };
    }).llama-cpp;

  llamaServer = lib.getExe' llamaCppCuda "llama-server";

  # The GGUF is too large (~17 GB) to be nix-managed; it lives outside /home
  # because the llama-swap unit sets ProtectHome=true. Place it with:
  #   sudo install -d -m0755 /var/lib/llama-models
  #   sudo mv ~/Downloads/Qwen3.6-35B-A3B-APEX-I-Compact.gguf /var/lib/llama-models/
  modelDir = "/var/lib/llama-models";
  modelPath = "${modelDir}/Qwen3.6-35B-A3B-APEX-I-Compact.gguf";
in
{
  # Ensure the models dir exists; the GGUF itself is dropped in manually.
  systemd.tmpfiles.rules = [
    "d ${modelDir} 0755 root root - -"
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
          ${llamaServer}
          --host 127.0.0.1 --port ''${PORT}
          -m ${modelPath}
          --alias qwen3.6-apex
          -ngl 999
          --n-cpu-moe 6
          -fa on
          --cache-type-k q8_0 --cache-type-v q8_0
          --ctx-size 131072
          --parallel 2 --kv-unified
          --threads 12 --threads-batch 12
          --cache-ram 4096
          --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0
          --jinja
          --no-webui
        '';
        aliases = [
          "claude-local"
          "qwen3.6-apex-compact"
          # ccr's small/fast (background) route targets this name; it resolves
          # to THIS same loaded process (no second model in VRAM). ccr's
          # `reasoning` transformer disables thinking on those requests.
          "qwen3.6-apex-nothink"
        ];
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
    serviceConfig.ProcSubset = lib.mkForce "all";
    environment = {
      # We build native sm_120 cubins, so there is no JIT cache to write
      # (and ProtectHome would block ~/.nv anyway).
      CUDA_CACHE_DISABLE = "1";
    };
  };
}
