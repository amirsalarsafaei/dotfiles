{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.custom.claudeCode;

  workEffortLevel = "xhigh";

  # Shared bash snippet inlined into every claude wrapper. It strips a custom
  # `--effort=LEVEL` (or `--effort LEVEL`) flag from the wrapper's args, exports
  # CLAUDE_CODE_EFFORT_LEVEL, and leaves the remaining args in "$@" for the
  # wrapped binary. With no --effort given it falls back to the
  # $CLAUDE_CODE_EFFORT_DEFAULT the wrapper exports (per-variant); if that is
  # empty too, the env var is left unset.
  #
  # We intercept --effort instead of letting Claude Code see it because the
  # binary persists /effort and `--effort` by rewriting settings.json, which here
  # is a read-only Nix symlink — so a persisted value can't stick and can even
  # clobber the link on next switch. The env var is honored at startup and never
  # touches disk, so it always wins and survives rebuilds.
  # Fail-closed geo guard for the normal-claude variant. Direct Anthropic
  # traffic from an Iranian/Tehran IP risks an account ban under US sanctions,
  # so refuse to launch until the outbound IP is verified as non-Iranian. Any
  # lookup failure (offline, DNS blocked, ipinfo down, empty JSON) counts as
  # unverified and blocks the launch by design.
  ipGuardText = ''
    ip_info=$(curl -sSf --max-time 5 https://ipinfo.io/json) || {
      printf 'claude: IP lookup failed; refusing to launch (fail-closed Iran guard)\n' >&2
      exit 2
    }
    country=$(printf '%s' "$ip_info" | jq -r '.country // ""')
    city=$(printf '%s' "$ip_info" | jq -r '.city // ""')
    if [ "$country" = "IR" ] || [ "$city" = "Tehran" ]; then
      printf 'claude: refusing to launch — IP looks Iranian (country=%s city=%s)\n' "$country" "$city" >&2
      exit 2
    fi
  '';

  effortParserText = ''
    _claude_effort="''${CLAUDE_CODE_EFFORT_DEFAULT:-}"
    _claude_rest=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --effort=*)
          _claude_effort="''${1#--effort=}"
          shift
          ;;
        --effort)
          if [ "$#" -lt 2 ]; then
            printf '%s: --effort requires a value\n' "$0" >&2
            exit 1
          fi
          _claude_effort="$2"
          shift 2
          ;;
        *)
          _claude_rest+=("$1")
          shift
          ;;
      esac
    done
    if [ -n "$_claude_effort" ]; then
      export CLAUDE_CODE_EFFORT_LEVEL="$_claude_effort"
    fi
    set -- "''${_claude_rest[@]}"
    unset _claude_effort _claude_rest
  '';

  workMcpConfigRel = ".config/claude-work/mcp-servers.json";
  workMcpConfigPath = "${config.home.homeDirectory}/${workMcpConfigRel}";
  workMcpServerName = "agentic-development-mcps";
  workMcpServers = {
    mcpServers = {
      "${workMcpServerName}" = {
        type = "http";
        url = "https://agentic-development-mcps.divar.dev/mcp";
      };
    };
  };

  # Tool-name prefixes registered by the single agentic-development-mcps
  # server (see ~/divar/platform-mcps src/platform_mcps/platform/server.py) —
  # every tool it exposes is named "<group>_<verb>", so a prefix glob deny
  # (mcp__<server>__<group>_*) hides that whole group from the model's tool
  # list rather than merely blocking calls to it. Keep in sync with that
  # repo's registered families if it adds/renames one.
  workMcpGroups = [
    "tempo"
    "metrics"
    "logs"
    "pyroscope"
    "codesearch"
    "sandboxing"
    "outline"
    "mattermost"
  ];

  # `claude-work --mcp-groups=tempo,logs` restricts the agentic-development-mcps
  # server to the named groups for that launch; the rest are hidden from the
  # model via a glob permission-deny (see workMcpGroups above), not just
  # blocked at call time. Omitting the flag keeps every group enabled
  # (today's default behavior). Runtime-only (not Nix-persisted) by design —
  # this is meant as a quick per-session toggle, mirroring effortParserText's
  # --effort flag.
  mcpGroupsParserText = ''
    _claude_mcp_groups=""
    _claude_rest2=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --mcp-groups=*)
          _claude_mcp_groups="''${1#--mcp-groups=}"
          shift
          ;;
        --mcp-groups)
          if [ "$#" -lt 2 ]; then
            printf '%s: --mcp-groups requires a value\n' "$0" >&2
            exit 1
          fi
          _claude_mcp_groups="$2"
          shift 2
          ;;
        *)
          _claude_rest2+=("$1")
          shift
          ;;
      esac
    done
    set -- "''${_claude_rest2[@]}"
    unset _claude_rest2

    _claude_mcp_disallow=()
    if [ -n "$_claude_mcp_groups" ]; then
      _claude_known_groups=" ${lib.concatStringsSep " " workMcpGroups} "
      IFS=',' read -ra _claude_wanted <<< "''${_claude_mcp_groups// /,}"
      for g in "''${_claude_wanted[@]}"; do
        case "$_claude_known_groups" in
          *" $g "*) ;;
          *)
            printf '%s: unknown --mcp-groups value %s (known: ${lib.concatStringsSep ", " workMcpGroups})\n' "$0" "$g" >&2
            exit 1
            ;;
        esac
      done
      for g in ${lib.concatStringsSep " " workMcpGroups}; do
        case " ''${_claude_wanted[*]} " in
          *" $g "*) ;;
          *) _claude_mcp_disallow+=("mcp__${workMcpServerName}__''${g}_*") ;;
        esac
      done
      unset _claude_wanted _claude_known_groups
    fi
    unset _claude_mcp_groups
  '';

  localMcpConfigRel = ".config/local-claude/mcp-servers.json";
  localMcpConfigPath = "${config.home.homeDirectory}/${localMcpConfigRel}";
  localMcpServers = {
    mcpServers = {
      exa = {
        type = "http";
        url = "https://mcp.exa.ai/mcp";
      };
      godot = {
        command = "npx";
        args = [ "@coding-solo/godot-mcp" ];
      };
    };
  };

  # Burp Suite's official MCP Server extension (PortSwigger/mcp-server) runs
  # an SSE server inside Burp itself, default http://127.0.0.1:9876 — only
  # reachable while Burp is running with the extension loaded and its MCP tab
  # enabled. Wired in on demand via --with-burp (burpParserText below) rather
  # than always-on: unlike the other MCP configs above, this one only ever
  # makes sense for the duration of an active pentest/security-testing
  # session, and there's no reason to give every Claude session standing
  # access to whatever Burp project happens to be open. If the extension's
  # port is changed from the default in Burp's MCP tab, update the url here
  # to match.
  burpMcpConfigRel = ".config/claude-shared/burp-mcp-servers.json";
  burpMcpConfigPath = "${config.home.homeDirectory}/${burpMcpConfigRel}";
  burpMcpServers = {
    mcpServers = {
      burp = {
        type = "sse";
        url = "http://127.0.0.1:9876/sse";
      };
    };
  };

  # `claude-work --with-burp` (or normal-claude/glm-claude/gap-claude) adds
  # the burp MCP server (burpMcpServers above) to that launch's
  # --mcp-config for the duration of the session. Runtime-only, mirroring
  # --effort/--mcp-groups: this is meant as a per-session toggle, not a
  # persisted setting.
  burpParserText = ''
    _claude_with_burp=0
    _claude_rest4=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --with-burp)
          _claude_with_burp=1
          shift
          ;;
        *)
          _claude_rest4+=("$1")
          shift
          ;;
      esac
    done
    set -- "''${_claude_rest4[@]}"
    unset _claude_rest4
  '';

  # Claude Code rewrites ~/.config/<variant>/.claude.json (its mutable runtime
  # state: projects, history, MRU lists) on nearly every action, and several
  # Claude processes routinely share one config dir. Concurrent, non-atomic
  # writes occasionally truncate it to 0 bytes; Claude then refuses to start and
  # leaves backups/.claude.json.corrupted.* behind (32 such files vs 5 good
  # backups at the time this was written). Claude itself keeps rolling
  # backups/.claude.json.backup.<epoch-ms> snapshots, so on every launch we
  # restore the newest VALID backup whenever the live file is missing, empty, or
  # unparseable. A healthy file is left untouched. This only runs on an
  # already-broken file, so it can never lose state the user still had.
  healClaudeState = pkgs.writeShellApplication {
    name = "heal-claude-json";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      dir="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      target="$dir/.claude.json"

      # Non-empty and parseable JSON? Nothing to do.
      if [ -s "$target" ] && jq -e . "$target" >/dev/null 2>&1; then
        exit 0
      fi

      # Pick the newest valid backup by its millisecond timestamp suffix.
      best=""
      best_ts=0
      for b in "$dir"/backups/.claude.json.backup.*; do
        [ -e "$b" ] || continue
        ts="''${b##*.backup.}"
        case "$ts" in
          "" | *[!0-9]*) continue ;;
        esac
        if [ "$ts" -gt "$best_ts" ] && jq -e . "$b" >/dev/null 2>&1; then
          best="$b"
          best_ts="$ts"
        fi
      done

      if [ -n "$best" ]; then
        cp -f "$best" "$target"
        printf 'heal-claude-json: restored %s from %s\n' "$target" "$best" >&2
      fi
    '';
  };

  glmClaude = pkgs.writeShellApplication {
    name = "glm-claude";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      key_file="$HOME/glm-key"
      if [ ! -s "$key_file" ]; then
        printf 'glm-claude: missing or empty %s\n' "$key_file" >&2
        exit 1
      fi

      ANTHROPIC_AUTH_TOKEN="$(cat "$key_file")"
      export ANTHROPIC_AUTH_TOKEN
      export ANTHROPIC_BASE_URL="https://api.raytone.ai"
      export ANTHROPIC_MODEL="glm-5.2"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.2"
      export CLAUDE_CODE_SUBAGENT_MODEL="glm-5.2"
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/glm-claude"
      # Default effort; override at runtime with --effort=LEVEL (e.g.
      # `glm-claude --effort=high`). See effortParserText for why this is an env
      # var rather than settings.json effortLevel.
      export CLAUDE_CODE_EFFORT_DEFAULT="${workEffortLevel}"
      ${effortParserText}
      # Restrict the agentic-development-mcps tool groups for this launch with
      # --mcp-groups=tempo,logs (see mcpGroupsParserText). Note this routes
      # whichever groups stay enabled through the raytone.ai backend above.
      ${mcpGroupsParserText}
      # Wire in Burp Suite's MCP server for this launch with --with-burp (see
      # burpParserText). Only useful while Burp + the MCP extension are
      # actually running.
      ${burpParserText}

      ${healClaudeState}/bin/heal-claude-json || true
      _claude_mcp_configs=(${workMcpConfigPath})
      if [ "$_claude_with_burp" = 1 ]; then
        _claude_mcp_configs+=(${burpMcpConfigPath})
      fi
      if [ "''${#_claude_mcp_disallow[@]}" -gt 0 ]; then
        exec ${pkgs.claude-code}/bin/claude --mcp-config "''${_claude_mcp_configs[@]}" \
          --disallowedTools "''${_claude_mcp_disallow[@]}" "$@"
      else
        exec ${pkgs.claude-code}/bin/claude --mcp-config "''${_claude_mcp_configs[@]}" "$@"
      fi
    '';
  };

  # Standalone binary form of ipGuardText, referenced by the SessionStart and
  # UserPromptSubmit hooks in normalSettings. Same fail-closed semantics: any
  # non-verified state exits 2, which Claude Code treats as a hard block for
  # UserPromptSubmit (stderr goes to the user) and as an error message shown
  # to the user for SessionStart. The wrapper's inlined copy of ipGuardText
  # (below) still fires first — the hooks are defense-in-depth for
  # already-running sessions and per-prompt checks in case the IP shifts
  # (VPN drop, tether swap) mid-session.
  claudeIpGuard = pkgs.writeShellApplication {
    name = "claude-ip-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ipGuardText;
  };

  # Shared statusline across every variant. Claude Code invokes the command
  # frequently (roughly every ~300ms while idle) and pipes a JSON blob to stdin
  # describing the session — model, cwd, transcript_path, running cost, lines
  # touched, output style, etc. We echo one line to stdout; that becomes the
  # bottom-of-terminal status. Context tokens are read from the tail of the
  # transcript's JSONL (last message with a `.message.usage`), so the number
  # reflects what was actually sent to the model on the previous turn — the
  # closest thing to a "live context size" the harness exposes.
  claudeStatusLine = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.git
      pkgs.kubectl
    ];
    text = ''
      input=$(cat)

      # Pull a JSON field with a default. jq failures fall back to $2 so a
      # malformed status payload never blanks the whole line.
      jq_get() {
        printf '%s' "$input" | jq -r "$1" 2>/dev/null || printf '%s' "$2"
      }

      model=$(jq_get '.model.display_name // .model.id // ""' "")
      cwd=$(jq_get '.workspace.current_dir // .cwd // ""' "")
      transcript=$(jq_get '.transcript_path // ""' "")
      cost=$(jq_get '.cost.total_cost_usd // 0' "0")
      added=$(jq_get '.cost.total_lines_added // 0' "0")
      removed=$(jq_get '.cost.total_lines_removed // 0' "0")
      style=$(jq_get '.output_style.name // ""' "")
      exceeds=$(jq_get '.exceeds_200k_tokens // false' "false")

      short_cwd="''${cwd/#$HOME/\~}"

      branch=""
      if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
                 || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
      fi

      # $TZ is exported by the variant wrapper (e.g. normal-claude -> Europe/Berlin,
      # claude-work -> Asia/Singapore) and inherited here since Claude Code runs
      # this command as its own subprocess; `date` honors it with no extra flags.
      now=$(date +'%H:%M %Z' 2>/dev/null || true)

      kctx=$(kubectl config current-context 2>/dev/null || true)

      # Context = input + cache_read + cache_creation of the most recent
      # assistant turn. Tail the last 40 lines so this stays O(1) even on
      # multi-MB transcripts; every assistant message carries usage, so 40 is
      # more than enough to find one. All errors swallowed → fall back to 0.
      ctx_tokens=0
      if [ -n "$transcript" ] && [ -f "$transcript" ]; then
        usage=$( { tail -n 40 "$transcript" 2>/dev/null \
                   | jq -c 'select(.message.usage != null) | .message.usage' 2>/dev/null \
                   | tail -n 1; } || true )
        if [ -n "$usage" ]; then
          ctx_tokens=$(printf '%s' "$usage" | jq -r \
            '((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' \
            2>/dev/null || printf 0)
        fi
      fi

      # Limit switches to 1M when Claude Code flags the >200k extended window.
      if [ "$exceeds" = "true" ]; then
        ctx_limit=1000000
        limit_label="1M"
      else
        ctx_limit=200000
        limit_label="200k"
      fi
      ctx_k=$(( ctx_tokens / 1000 ))
      ctx_pct=$(( ctx_tokens * 100 / ctx_limit ))

      cost_fmt=$(printf '$%.2f' "$cost")

      parts=()
      [ -n "$model" ]     && parts+=("[$model]")
      [ -n "$short_cwd" ] && parts+=("$short_cwd")
      [ -n "$branch" ]    && parts+=("($branch)")
      [ -n "$kctx" ]      && parts+=("k8s:$kctx")
      parts+=("ctx ''${ctx_k}k/''${limit_label} (''${ctx_pct}%)")
      # Third-party endpoints (raytone/GLM, gapgpt, the local llama-swap) don't
      # report Anthropic-billed cost, so total_cost_usd is stuck at 0 and $0.00
      # is just noise. Only show cost when there's something to show.
      parts+=("$cost_fmt")
      if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
        parts+=("+$added -$removed")
      fi
      [ -n "$style" ] && [ "$style" != "default" ] && parts+=("$style")
      [ -n "$now" ] && parts+=("$now")

      # Join with ' | '.
      out=""
      for p in "''${parts[@]}"; do
        if [ -z "$out" ]; then out="$p"; else out="$out | $p"; fi
      done
      printf '%s\n' "$out"
    '';
  };

  # Vanilla claude → Anthropic direct. Nothing set beyond the isolated config
  # dir, the shared effort/heal helpers, and the ipGuardText prehook that
  # refuses to launch from an Iranian IP (fail-closed).
  normalClaude = pkgs.writeShellApplication {
    name = "normal-claude";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.tzdata
    ];
    text = ''
      ${ipGuardText}
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/normal-claude"
      export TZ="Europe/Berlin"
      export TZDIR="${pkgs.tzdata}/share/zoneinfo"
      ${effortParserText}
      # Wire in Burp Suite's MCP server for this launch with --with-burp (see
      # burpParserText). Only useful while Burp + the MCP extension are
      # actually running.
      ${burpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      if [ "$_claude_with_burp" = 1 ]; then
        exec ${pkgs.claude-code}/bin/claude --mcp-config ${burpMcpConfigPath} "$@"
      else
        exec ${pkgs.claude-code}/bin/claude "$@"
      fi
    '';
  };

  gapClaude = pkgs.writeShellApplication {
    name = "gap-claude";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/gap-claude"
      export ANTHROPIC_API_KEY="${secrets.gapgpt.apiKey or ""}"
      export ANTHROPIC_BASE_URL="https://api.gapgpt.app/"
      ${effortParserText}
      ${burpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      if [ "$_claude_with_burp" = 1 ]; then
        exec ${pkgs.claude-code}/bin/claude --mcp-config ${burpMcpConfigPath} "$@"
      else
        exec ${pkgs.claude-code}/bin/claude "$@"
      fi
    '';
  };

  claudeWork = pkgs.writeShellApplication {
    name = "claude-work";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.tzdata
    ];
    text = ''
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/claude-work"
      export TZ="Asia/Singapore"
      export TZDIR="${pkgs.tzdata}/share/zoneinfo"
      # Default effort for the work variant; override at runtime with --effort=.
      export CLAUDE_CODE_EFFORT_DEFAULT="${workEffortLevel}"
      ${effortParserText}
      # Restrict the agentic-development-mcps tool groups for this launch with
      # --mcp-groups=tempo,logs (see mcpGroupsParserText). Omit to keep every
      # group enabled.
      ${mcpGroupsParserText}
      # Wire in Burp Suite's MCP server for this launch with --with-burp (see
      # burpParserText). Only useful while Burp + the MCP extension are
      # actually running.
      ${burpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      _claude_mcp_configs=(${workMcpConfigPath})
      if [ "$_claude_with_burp" = 1 ]; then
        _claude_mcp_configs+=(${burpMcpConfigPath})
      fi
      if [ "''${#_claude_mcp_disallow[@]}" -gt 0 ]; then
        exec ${pkgs.claude-code}/bin/claude --mcp-config "''${_claude_mcp_configs[@]}" \
          --disallowedTools "''${_claude_mcp_disallow[@]}" "$@"
      else
        exec ${pkgs.claude-code}/bin/claude --mcp-config "''${_claude_mcp_configs[@]}" "$@"
      fi
    '';
  };

  # Local-model variant: a thin wrapper that points Claude Code at a local
  # GGUF served by llama-swap (see hosts/g14/local-llm.nix). LiteLLM exposes an
  # Anthropic-compatible /v1/messages API and translates to OpenAI
  # chat-completions for llama-swap.
  localClaude = pkgs.writeShellApplication {
    name = "local-claude";
    runtimeInputs = [
      pkgs.claude-code
      pkgs.nodejs
    ];
    text = ''
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/local-claude"
      export ANTHROPIC_BASE_URL="${localAnthropicBaseUrl}"
      export ANTHROPIC_AUTH_TOKEN="${localProxyKey}"
      # Pin the model names so the UI reflects reality and nothing can fall
      # through to Anthropic.
      #   - main model      -> qwen3.6-apex
      #   - small/fast model-> qwen3.6-apex-nothink  (LiteLLM model group that
      #     injects chat_template_kwargs.enable_thinking=false on the
      #     thinking-less background chores: titles, topic checks, summaries).
      # Both names resolve to the SAME loaded llama-swap process (alias), so there
      # is no second model in VRAM and no swapping.
      export ANTHROPIC_MODEL="${localModel}"
      export ANTHROPIC_SMALL_FAST_MODEL="${localModelFast}"
      # Effort override at runtime: --effort=LEVEL (e.g. `local-claude --effort=high`).
      # No default here — the local model is slow, so leave effort unset unless asked.
      ${effortParserText}
      # Restore .claude.json from a backup if a prior run left it corrupted
      # (same self-heal the other variants get; see healClaudeState).
      ${healClaudeState}/bin/heal-claude-json || true
      exec claude --mcp-config "${localMcpConfigPath}" "$@"
    '';
  };

  # LiteLLM routing config lives in hosts/g14/local-llm.nix. Both model groups
  # point at the same single llama-swap model and inject llama.cpp's Qwen3
  # no-thinking chat_template_kwargs. Timeouts are generous
  # since local generation is far slower than the cloud.
  localAnthropicBaseUrl = "http://127.0.0.1:18081";
  localProxyKey = "sk-local";
  localModel = "qwen3.6-apex";
  localModelFast = "qwen3.6-apex-nothink";

  defaultPlugins = {
    "gopls-lsp@claude-plugins-official" = true;
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
    "lua-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
  };

  pluginType = with lib.types; attrsOf bool;

  mkSettings =
    variant: base:
    let
      plugins = cfg.plugins.default // cfg.plugins.${variant};
    in
    # Default statusLine listed first so a variant's `base` can override it by
    # setting its own `statusLine` — none currently do.
    {
      statusLine = {
        type = "command";
        command = "${claudeStatusLine}/bin/claude-statusline";
      };
    }
    // base
    // lib.optionalAttrs (plugins != { } || base ? enabledPlugins) {
      # Merge, don't clobber: `base` may carry variant-specific entries (e.g.
      # workSettings' conditional "devar@divar"); cfg.plugins toggles win.
      enabledPlugins = (base.enabledPlugins or { }) // plugins;
    };

  localSettings = {
    # Explicit toggle so nothing silently disables auto-compact for the local
    # model (small effective context; letting the conversation grow past the
    # window is far worse than the compaction cost). The env vars below tune
    # *when* it fires; this makes sure it fires at all.
    autoCompactEnabled = true;
    env = {
      CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "80";
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "131072";
    };
    permissions = {
      allow = [
        "Bash(*)"
        "mcp__exa"
      ];
      # The local model has no access to Anthropic's hosted WebFetch/WebSearch
      # (those require a paid Anthropic subscription and go through their
      # backend). Deny them so the model doesn't try — it should reach for the
      # exa MCP tools instead (see CLAUDE.md addendum below).
      deny = [
        "WebFetch"
        "WebSearch"
      ];
      defaultMode = "auto";
    };
    theme = "dark";
  };

  # Register the local devar plugin checkout as the "divar" marketplace so the
  # plugin below is enabled non-interactively instead of via `/plugin
  # marketplace add`. Gated on enableDevar (set by modules/work.nix → isWork)
  # so it lands only on the work laptop, the host that has the ~/divar/devar
  # checkout (the inputs.devar flake-input path). A directory source needs no
  # clone and no git.divar.cloud SSH key, and a directory path (unlike an
  # SCP-style git URL) is a valid source that /doctor accepts. The nested
  # `source` shape mirrors what Claude Code writes to known_marketplaces.json.
  # Shared by workSettings and normalSettings — the work laptop runs both
  # variants and wants devar (flags CLI + divarrpc lookups) in either.
  devarMarketplace = lib.optionalAttrs cfg.enableDevar {
    divar = {
      source = {
        source = "directory";
        path = "${config.home.homeDirectory}/divar/devar";
      };
    };
  };

  # Divar SDUI helper: `devar flags` cookie editor + offline divarrpc
  # widget/payload/enum lookup (CLI + the `devar` MCP server) + the Divar
  # skill set. plugin "devar" @ marketplace "divar" (devarMarketplace above).
  devarPlugin = lib.optionalAttrs cfg.enableDevar {
    "devar@divar" = true;
  };

  # devar plugin CLI (flags cookie editor + offline divarrpc lookup:
  # widget/struct/list/enum/support/services/godoc/grep/usages/repos) plus its
  # bundled MCP server. Server id is plugin_<plugin>_<server> =
  # plugin_devar_devar; trust the whole server so its read-only lookup tools
  # don't prompt.
  devarPermissions = lib.optionalAttrs cfg.enableDevar {
    allow = [
      "Bash(devar:*)"
      "mcp__plugin_devar_devar"
    ];
  };

  workSettings = {
    permissions = {
      allow = [
        "Bash(go:*)"
        "Bash(git pull:*)"
        "Bash(git checkout:*)"
        "Bash(jq:*)"
        "Bash(yq:*)"
        "Bash(rg:*)"
        "Bash(grep:*)"
        "Bash(find:*)"
        "Bash(xxd:*)"
        "WebFetch"
        "Bash(DIVAR_RPC_TESTING=1 go:*)"
      ]
      ++ (devarPermissions.allow or [ ]);
      deny = [
        "Bash(kubectl:*)"
        "Bash(k *)"
      ];
      defaultMode = "auto";
    };
    extraKnownMarketplaces = devarMarketplace;
    # Only the variant-specific additions here; the shared LSP plugins come from
    # cfg.plugins.default and are merged in by mkSettings.
    enabledPlugins = {
      # Figma's official plugin: registers the remote Figma MCP server
      # (https://mcp.figma.com/mcp, OAuth) so the work Claude can pull design
      # data — components, variables, layout — for design-to-code. Same built-in
      # "claude-plugins-official" marketplace as the LSP plugins, so it needs no
      # extraKnownMarketplaces entry. First use needs a one-time browser OAuth:
      # run `/plugin` (or `/mcp`) and authenticate; that token lives in mutable
      # runtime state, not in this Nix-managed settings.json.
      "figma@claude-plugins-official" = true;
    }
    // devarPlugin;
    # effortLevel intentionally omitted: set via the CLAUDE_CODE_EFFORT_LEVEL
    # env var in claudeWork's wrapper instead (see note there). Keeping it here
    # too would be a redundant second source of truth, and the env var wins.
    theme = "dark";
    outputStyle = "concise";
    skipAutoPermissionPrompt = true;
  };

  gapSettings = {
    theme = "dark";
  };

  normalSettings = {
    theme = "dark";
    # devar wiring is shared with workSettings: gated on cfg.enableDevar, which
    # modules/work.nix only sets true on the work laptop (the host with the
    # ~/divar/devar checkout). On any other host these are all empty attrsets.
    extraKnownMarketplaces = devarMarketplace;
    enabledPlugins = devarPlugin;
    permissions = devarPermissions;
    # Belt-and-suspenders IP guard: the wrapper prehook blocks initial launch,
    # SessionStart re-checks on /resume of an already-running claude, and
    # UserPromptSubmit re-checks every message so a mid-session VPN drop is
    # caught before the next request hits Anthropic. Hook exit 2 hard-blocks
    # the prompt (UserPromptSubmit contract) and surfaces the stderr banner.
    # Timeout is generous (10s) but curl's own --max-time 5 caps most calls.
    hooks = {
      SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = "${claudeIpGuard}/bin/claude-ip-guard";
              timeout = 10;
            }
          ];
        }
      ];
      UserPromptSubmit = [
        {
          hooks = [
            {
              type = "command";
              command = "${claudeIpGuard}/bin/claude-ip-guard";
              timeout = 10;
            }
          ];
        }
      ];
    };
  };

  withOverrides =
    base:
    base
    // lib.optionalAttrs (cfg.skillOverrides != { }) {
      skillOverrides = cfg.skillOverrides;
    };

  nixManagedNote = "settings.json is Nix-managed (home/modules/programs/development/claude-code.nix in your dotfiles flake) — edits won't persist; change Nix and rebuild.\n";

  # `claude` on PATH is an interactive picker: it asks which variant to launch
  # and execs it with every arg intact, so `claude --resume <session-id>` (or
  # any other flags) flow through to the chosen variant. Only the enabled cloud
  # variants are offered; local-claude is intentionally excluded (launch it
  # explicitly via `local-claude`). The real claude-code binary is NOT put on
  # PATH — each variant references it by absolute store path, and local-claude
  # points ccr at it via CLAUDE_CODE_COMMAND (see localClaude) so ccr never
  # recurses into this picker.
  pickerEntry = tag: name: desc: bin: {
    inherit
      tag
      name
      desc
      bin
      ;
  };
  pickerVariants =
    lib.optional cfg.enable (pickerEntry "gap" "gap-claude" "gapgpt cloud" gapClaude)
    ++ lib.optional cfg.enableGlm (pickerEntry "glm" "glm-claude" "GLM via raytone" glmClaude)
    ++ lib.optional cfg.enableWork (pickerEntry "work" "claude-work" "Divar work, xhigh" claudeWork)
    ++ lib.optional cfg.enableNormal (
      pickerEntry "normal" "normal-claude" "Anthropic direct, IP-guarded" normalClaude
    );

  pickerTags = map (v: v.tag) pickerVariants;
  pickerCases = lib.concatStringsSep "\n" (
    map (
      v:
      "          ${v.tag}) printf 'launching %s (%s)\\n' \"${v.name}\" \"${v.desc}\"; exec ${v.bin}/bin/${v.name} \"$@\" ;;"
    ) pickerVariants
  );

  claudePicker = pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
            _tags=( ${lib.concatStringsSep " " pickerTags} )
            if [ "''${#_tags[@]}" -eq 0 ]; then
              printf 'claude: no variants enabled. Keep custom.claudeCode.enable (gap) or set enableGlm/enableWork.\n' >&2
              exit 1
            fi
            PS3="Which claude? "
            select _pick in "''${_tags[@]}" quit; do
              case "$_pick" in
      ${pickerCases}
                quit)
                  exit 0
                  ;;
                *)
                  printf 'invalid choice: %s\n' "$REPLY" >&2
                  ;;
              esac
            done
    '';
  };
in
{
  options.custom.claudeCode = {
    enable = lib.mkEnableOption "Install claude-code and the gap-claude wrapper";
    enableGlm = lib.mkEnableOption "Route the default claude command through GLM";
    enableWork = lib.mkEnableOption "Install the claude-work variant (work-host only)";
    enableLocal = lib.mkEnableOption "Install the local-claude variant (LiteLLM -> local llama-swap model)";
    enableNormal = lib.mkEnableOption ''
      the normal-claude variant: vanilla Anthropic-direct claude wrapped with
      a fail-closed Iran/Tehran IP guard (ipinfo.io lookup before exec). Any
      lookup failure blocks the launch — this is deliberate, since connecting
      to Anthropic from a sanctioned region risks the account
    '';
    enableDevar = lib.mkEnableOption ''
      the Divar `devar` plugin in the work variant: the directory-sourced
      "divar" marketplace (~/divar/devar) and the `devar@divar` plugin entry.
      Set by modules/work.nix (isWork) so it lands only on the work laptop —
      the host that has the ~/divar/devar checkout. Other claude-work hosts
      (e.g. g14) get the variant without devar
    '';

    plugins = {
      default = lib.mkOption {
        type = pluginType;
        default = defaultPlugins;
        description = ''
          Claude Code plugins enabled for every variant. Set a plugin to false
          here to disable it globally, or override individual variants below.
        '';
      };

      gap = lib.mkOption {
        type = pluginType;
        default = { };
        example = lib.literalExpression ''
          {
            "gopls-lsp@claude-plugins-official" = false;
          }
        '';
        description = "Per-plugin overrides for the gap-claude variant.";
      };

      work = lib.mkOption {
        type = pluginType;
        default = { };
        description = "Per-plugin overrides for the claude-work variant.";
      };

      local = lib.mkOption {
        type = pluginType;
        default = { };
        description = "Per-plugin overrides for the local-claude variant.";
      };

      normal = lib.mkOption {
        type = pluginType;
        default = { };
        description = "Per-plugin overrides for the normal-claude variant.";
      };
    };

    defaultSkillMode = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "on"
          "user-invocable-only"
          "name-only"
          "off"
        ]);
      default = "user-invocable-only";
      description = ''
        Default visibility applied to every skill installed via
        `custom.agentSkills` (work skills, samber, local — anything in the
        catalog). The agent-skills module computes the installed skill set and
        writes one `skillOverrides` entry per skill at this mode.

        Per-skill entries in `skillOverrides` take precedence over this
        default. Set to null to disable the automatic default entirely.
      '';
    };

    skillOverrides = lib.mkOption {
      type =
        with lib.types;
        attrsOf (enum [
          "on"
          "user-invocable-only"
          "name-only"
          "off"
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          golang-design-patterns = "on";
        }
      '';
      description = ''
        Per-skill visibility overrides written to settings.json under
        `skillOverrides`. Applies to all enabled Claude Code variants. Entries
        here win over the `defaultSkillMode` auto-default.

        Values:
          - "on"                  : auto-listed to the model
          - "user-invocable-only" : installed and `/skill-name` works, hidden from model
          - "name-only"           : name listed, description hidden
          - "off"                 : fully hidden
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [
        claudePicker
        gapClaude
      ]
      ++ lib.optional cfg.enableGlm glmClaude;
      home.file.".config/gap-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "gap" gapSettings)
      );
      home.file.".config/gap-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableGlm {
      home.file.".config/glm-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" workSettings)
      );
      home.file.".config/glm-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
      home.file.".config/claude-work/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" workSettings)
      );
      home.file.".config/claude-work/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf (cfg.enableWork || cfg.enableGlm) {
      # Shared by claude-work and glm-claude — both exec with --mcp-config
      # pointed at this same file (workMcpConfigPath).
      home.file.${workMcpConfigRel}.text = builtins.toJSON workMcpServers;
    })
    (lib.mkIf (cfg.enable || cfg.enableWork || cfg.enableGlm || cfg.enableNormal) {
      # Shared by every variant's --with-burp flag (burpParserText).
      home.file.${burpMcpConfigRel}.text = builtins.toJSON burpMcpServers;
    })
    (lib.mkIf cfg.enableLocal {
      home.packages = [ localClaude ];
      home.file.".config/local-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "local" localSettings)
      );
      home.file.".config/local-claude/CLAUDE.md".text =
        nixManagedNote
        + "Use mcp__exa__web_search_exa for web searches and mcp__exa__web_fetch_exa for webpage retrieval. The built-in WebSearch and WebFetch tools are unavailable with the local model.\n";
      home.file.${localMcpConfigRel}.text = builtins.toJSON localMcpServers;
    })
    (lib.mkIf cfg.enableNormal {
      home.packages = [ normalClaude ];
      home.file.".config/normal-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "normal" normalSettings)
      );
      home.file.".config/normal-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf (cfg.enable || cfg.enableWork || cfg.enableLocal || cfg.enableNormal) {
      # Claude Code persists runtime changes (/effort, enabling a plugin, theme,
      # adding a marketplace, …) by rewriting settings.json — which replaces the
      # read-only Nix symlink with a plain file. With home-manager's
      # backupFileExtension = "backup", the next `home-manager switch` moves that
      # file aside to settings.json.backup, and then FAILS the whole rebuild the
      # moment a settings.json.backup from an earlier clobber is already there
      # ("would be clobbered"). settings.json is fully reproducible from this
      # module, so drop the clobbered copy (and any stale backup) before the link
      # check — exactly like obsidianClobberGuard does for the vault. Runs every
      # switch, so it self-heals instead of needing a manual `rm`.
      home.activation.claudeSettingsClobberGuard = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
        lib.concatMapStringsSep "\n"
          (dir: ''
            s="${config.home.homeDirectory}/${dir}/settings.json"
            if [ -e "$s" ] && [ ! -L "$s" ]; then
              run rm -f $VERBOSE_ARG "$s"
            fi
            run rm -f $VERBOSE_ARG "$s.backup"
          '')
          (
            lib.optional cfg.enable ".config/gap-claude"
            ++ lib.optional cfg.enableGlm ".config/glm-claude"
            ++ lib.optional cfg.enableWork ".config/claude-work"
            ++ lib.optional cfg.enableLocal ".config/local-claude"
            ++ lib.optional cfg.enableNormal ".config/normal-claude"
          )
      );
    })
  ];
}
