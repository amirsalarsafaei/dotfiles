{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.custom.claudeCode;

  # The zellij status-bar plugin and its Claude Code hook bridge are one
  # package; the plugin half is used by home/modules/programs/terminal/zelij.nix.
  zellaude = pkgs.callPackage ../../../../pkgs/zellaude.nix { };

  workEffortLevel = "xhigh";

  ipGuardText = ''
    country=""

    ip_info=$(curl -sfL --connect-timeout 3 --max-time 10 \
      https://api.country.is/ 2>/dev/null) || ip_info=""
    if [ -n "$ip_info" ]; then
      country=$(printf '%s' "$ip_info" | jq -er \
        '.country | strings | ascii_upcase | select(test("^[A-Z]{2}$"))' \
        2>/dev/null) || country=""
    fi

    if [ -z "$country" ]; then
      ip_info=$(curl -sfL --connect-timeout 3 --max-time 10 \
        https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null) || ip_info=""
      if [ -n "$ip_info" ]; then
        while IFS='=' read -r key value; do
          if [ "$key" = "loc" ]; then
            country="''${value^^}"
            break
          fi
        done <<<"$ip_info"
        case "$country" in
          [A-Z][A-Z]) ;;
          *) country="" ;;
        esac
      fi
    fi

    if [ -z "$country" ]; then
      ip_info=$(curl -sfL --connect-timeout 3 --max-time 10 \
        https://ipwho.is/ 2>/dev/null) || ip_info=""
      if [ -n "$ip_info" ]; then
        country=$(printf '%s' "$ip_info" | jq -er \
          'select(.success == true) | .country_code | strings | ascii_upcase | select(test("^[A-Z]{2}$"))' \
          2>/dev/null) || country=""
      fi
    fi

    if [ -z "$country" ]; then
      printf 'claude: country lookup failed across all providers; refusing to launch (fail-closed Iran guard)\n' >&2
      exit 2
    fi

    if [ "$country" = "IR" ]; then
      printf 'claude: refusing to launch — IP looks Iranian (country=%s)\n' "$country" >&2
      exit 2
    fi
  '';

  mkBoolFlagParser =
    { flag, resultVar }:
    ''
      ${resultVar}=0
      _claude_flag_rest=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          ${flag})
            ${resultVar}=1
            shift
            ;;
          *)
            _claude_flag_rest+=("$1")
            shift
            ;;
        esac
      done
      set -- "''${_claude_flag_rest[@]}"
      unset _claude_flag_rest
    '';

  mkValueFlagParser =
    { flag, resultVar }:
    ''
      _claude_flag_rest=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          ${flag}=*)
            ${resultVar}="''${1#${flag}=}"
            shift
            ;;
          ${flag})
            if [ "$#" -lt 2 ]; then
              printf '%s: ${flag} requires a value\n' "$0" >&2
              exit 1
            fi
            ${resultVar}="$2"
            shift 2
            ;;
          *)
            _claude_flag_rest+=("$1")
            shift
            ;;
        esac
      done
      set -- "''${_claude_flag_rest[@]}"
      unset _claude_flag_rest
    '';

  effortParserText = ''
    _claude_effort="''${CLAUDE_CODE_EFFORT_DEFAULT:-}"
    ${mkValueFlagParser {
      flag = "--effort";
      resultVar = "_claude_effort";
    }}
    if [ -n "$_claude_effort" ]; then
      export CLAUDE_CODE_EFFORT_LEVEL="$_claude_effort"
    fi
    unset _claude_effort
  '';

  workMcpConfigRel = ".config/work-claude/mcp-servers.json";
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

  mcpGroupsParserText = ''
    _claude_mcp_groups=""
    ${mkValueFlagParser {
      flag = "--mcp-groups";
      resultVar = "_claude_mcp_groups";
    }}

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

  agenticMcpParserText = mkBoolFlagParser {
    flag = "--agentic-mcps";
    resultVar = "_claude_agentic_mcps";
  };

  gitlabMcpParserText = mkBoolFlagParser {
    flag = "--gitlab-mcp";
    resultVar = "_claude_gitlab_mcp";
  };

  gitlabMcpDenyText = ''
    if [ "$_claude_gitlab_mcp" -eq 0 ]; then
      _claude_mcp_disallow+=("mcp__${workMcpServerName}__gitlab_*")
    fi
    unset _claude_gitlab_mcp
  '';

  noDevarParserText = mkBoolFlagParser {
    flag = "--no-devar";
    resultVar = "_claude_no_devar";
  };

  noDevarSettingsArgText = ''
    _claude_extra_args=()
    if [ "$_claude_no_devar" -eq 1 ]; then
      _claude_extra_args+=(--settings '{"enabledPlugins":{"devar@divar":false}}')
    fi
    unset _claude_no_devar
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

  healClaudeState = pkgs.writeShellApplication {
    name = "heal-claude-json";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      dir="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      target="$dir/.claude.json"

      if [ -s "$target" ] && jq -e . "$target" >/dev/null 2>&1; then
        exit 0
      fi

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

  mkKeyAuth =
    {
      name,
      keyFile,
      authVar,
    }:
    ''
      key_file="$HOME/${keyFile}"
      if [ ! -s "$key_file" ]; then
        printf '${name}: missing or empty %s\n' "$key_file" >&2
        exit 1
      fi

      ${authVar}="$(cat "$key_file")"
      export ${authVar}
    '';

  workWrapperTail = ''
    ${effortParserText}
    ${mcpGroupsParserText}
    ${gitlabMcpParserText}
    ${gitlabMcpDenyText}
    ${noDevarParserText}

    ${healClaudeState}/bin/heal-claude-json || true
    ${noDevarSettingsArgText}
    if [ "''${#_claude_mcp_disallow[@]}" -gt 0 ]; then
      exec ${pkgs.claude-code}/bin/claude --mcp-config ${workMcpConfigPath} \
        --disallowedTools "''${_claude_mcp_disallow[@]}" "''${_claude_extra_args[@]}" "$@"
    else
      exec ${pkgs.claude-code}/bin/claude --mcp-config ${workMcpConfigPath} "''${_claude_extra_args[@]}" "$@"
    fi
  '';

  glmClaude = pkgs.writeShellApplication {
    name = "glm-claude";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "glm-claude";
        keyFile = "glm-key";
        authVar = "ANTHROPIC_AUTH_TOKEN";
      }}
      export ANTHROPIC_BASE_URL="https://api.raytone.ai"
      export ANTHROPIC_MODEL="glm-5.2[1m]"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2[1m]"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.2[1m]"
      export CLAUDE_CODE_SUBAGENT_MODEL="glm-5.2[1m]"
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/glm-claude"
      export CLAUDE_CODE_EFFORT_DEFAULT="${workEffortLevel}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576"
      export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"
      ${workWrapperTail}
    '';
  };

  deepseekClaude = pkgs.writeShellApplication {
    name = "deepseek-claude";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "deepseek-claude";
        keyFile = "deepseek-key";
        authVar = "ANTHROPIC_API_KEY";
      }}
      export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
      export ANTHROPIC_MODEL="deepseek-v4-pro"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-flash"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
      export ANTHROPIC_SMALL_FAST_MODEL="deepseek-v4-flash"
      export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/deepseek-claude"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576"
      export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"
      ${workWrapperTail}
    '';
  };

  claudeIpGuard = pkgs.writeShellApplication {
    name = "claude-ip-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ipGuardText;
  };

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

      now=$(date +'%H:%M %Z' 2>/dev/null || true)

      kctx=$(kubectl config current-context 2>/dev/null || true)

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

      if [ "$exceeds" = "true" ]; then
        ctx_limit=1000000
        limit_label="1M"
      else
        ctx_limit=200000
        limit_label="200k"
      fi
      ctx_k=$(( ctx_tokens / 1000 ))
      ctx_pct=$(( ctx_tokens * 100 / ctx_limit ))

      parts=()
      [ -n "$model" ]     && parts+=("[$model]")
      [ -n "$short_cwd" ] && parts+=("$short_cwd")
      [ -n "$branch" ]    && parts+=("($branch)")
      [ -n "$kctx" ]      && parts+=("k8s:$kctx")
      parts+=("ctx ''${ctx_k}k/''${limit_label} (''${ctx_pct}%)")
      if [ "$(printf '%s' "$input" | jq -r '(.cost.total_cost_usd // 0) > 0' 2>/dev/null)" = "true" ]; then
        parts+=("$(printf '$%.2f' "$cost")")
      fi
      if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
        parts+=("+$added -$removed")
      fi
      [ -n "$style" ] && [ "$style" != "default" ] && parts+=("$style")
      [ -n "$now" ] && parts+=("$now")

      out=""
      for p in "''${parts[@]}"; do
        if [ -z "$out" ]; then out="$p"; else out="$out | $p"; fi
      done
      printf '%s\n' "$out"
    '';
  };

  glmUsage = pkgs.writeShellApplication {
    name = "glm-usage";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      export GLM_PRICE_INPUT="''${GLM_PRICE_INPUT-${toString cfg.glmPrices.input}}"
      export GLM_PRICE_OUTPUT="''${GLM_PRICE_OUTPUT-${toString cfg.glmPrices.output}}"
      export GLM_PRICE_CACHE_READ="''${GLM_PRICE_CACHE_READ-${toString cfg.glmPrices.cacheRead}}"
      export GLM_PRICE_CACHE_CREATE="''${GLM_PRICE_CACHE_CREATE-${toString cfg.glmPrices.cacheCreate}}"
      export GLM_BILLING_DAY="''${GLM_BILLING_DAY-${toString cfg.glmBillingDay}}"
      exec ${pkgs.python3}/bin/python3 ${./glm-usage.py} "$@"
    '';
  };

  glmStatusLine = pkgs.writeShellApplication {
    name = "glm-claude-statusline";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      input=$(cat)
      base=$(${claudeStatusLine}/bin/claude-statusline <<<"$input" 2>/dev/null || true)
      seg=$(${glmUsage}/bin/glm-usage statusline 2>/dev/null || true)
      if [ -n "$seg" ] && [ -n "$base" ]; then
        printf '%s | %s\n' "$base" "$seg"
      elif [ -n "$base" ]; then
        printf '%s\n' "$base"
      else
        printf 'glm\n'
      fi
    '';
  };

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
      ${agenticMcpParserText}
      ${gitlabMcpParserText}
      ${noDevarParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${noDevarSettingsArgText}
      if [ "$_claude_agentic_mcps" -eq 1 ]; then
        if [ "$_claude_gitlab_mcp" -eq 1 ]; then
          exec ${pkgs.claude-code}/bin/claude --mcp-config ${workMcpConfigPath} "''${_claude_extra_args[@]}" "$@"
        else
          exec ${pkgs.claude-code}/bin/claude --mcp-config ${workMcpConfigPath} \
            --disallowedTools "mcp__${workMcpServerName}__gitlab_*" "''${_claude_extra_args[@]}" "$@"
        fi
      else
        exec ${pkgs.claude-code}/bin/claude "''${_claude_extra_args[@]}" "$@"
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
      ${healClaudeState}/bin/heal-claude-json || true
      exec ${pkgs.claude-code}/bin/claude "$@"
    '';
  };

  claudeWork = pkgs.writeShellApplication {
    name = "work-claude";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.tzdata
    ];
    text = ''
      ${ipGuardText}
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/work-claude"
      export TZ="Asia/Singapore"
      export TZDIR="${pkgs.tzdata}/share/zoneinfo"
      export CLAUDE_CODE_EFFORT_DEFAULT="${workEffortLevel}"
      ${workWrapperTail}
    '';
  };

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
      export ANTHROPIC_MODEL="${localModel}"
      export ANTHROPIC_SMALL_FAST_MODEL="${localModelFast}"
      ${effortParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      exec claude --mcp-config "${localMcpConfigPath}" "$@"
    '';
  };

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

  # zellij's status bar (zellaude, see home/modules/programs/terminal/zelij.nix)
  # shows what each Claude pane is doing — thinking, running a tool, waiting on
  # a permission prompt — and it learns that from these hooks: each one pipes
  # the event into the plugin with `zellij pipe`. The script no-ops instantly
  # outside zellij, so it is safe on every variant.
  #
  # These replaced a hook that prefixed the zellij tab name with a bell glyph on
  # Notification/Stop. Two things renaming tabs at once (that hook and a zsh
  # precmd hook that named the tab after the cwd) made the bar flicker, and the
  # plugin says strictly more than the glyph did.
  #
  # zellaude normally installs itself into ~/.claude/settings.json on first run;
  # that file is generated from this module, so the plugin's copy is patched out
  # (pkgs/zellaude.nix) and the registration lives here instead.
  zellaudeHooks =
    let
      entry = [
        {
          hooks = [
            {
              type = "command";
              command = "${zellaude.hook}/bin/zellaude-hook";
              timeout = 5;
              async = true;
            }
          ];
        }
      ];
    in
    lib.genAttrs [
      "PreToolUse"
      "PostToolUse"
      "PostToolUseFailure"
      "UserPromptSubmit"
      "PermissionRequest"
      "Notification"
      "Stop"
      "SubagentStop"
      "SessionStart"
      "SessionEnd"
    ] (_: entry);

  mkSettings =
    variant: base:
    let
      plugins = cfg.plugins.default // cfg.plugins.${variant};
    in
    {
      statusLine = {
        type = "command";
        command = "${claudeStatusLine}/bin/claude-statusline";
      };
    }
    // base
    // lib.optionalAttrs (plugins != { } || base ? enabledPlugins) {
      enabledPlugins = (base.enabledPlugins or { }) // plugins;
    }
    // {
      hooks = lib.zipAttrsWith (_: lib.concatLists) [
        zellaudeHooks
        (base.hooks or { })
      ];
    };

  localSettings = {
    autoCompactEnabled = true;
    env = {
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "131072";
    };
    permissions = {
      allow = [
        "Bash(*)"
        "mcp__exa"
      ];
      deny = [
        "WebFetch"
        "WebSearch"
      ];
      defaultMode = "auto";
    };
    theme = "dark";
  };

  devarMarketplace = lib.optionalAttrs cfg.enableDevar {
    divar = {
      source = {
        source = "directory";
        path = "${config.home.homeDirectory}/divar/devar";
      };
    };
  };

  devarPlugin = lib.optionalAttrs cfg.enableDevar {
    "devar@divar" = true;
  };

  devarPermissions = lib.optionalAttrs cfg.enableDevar {
    allow = [
      "Bash(devar:*)"
      "mcp__plugin_devar_devar"
      "Read(/${config.home.homeDirectory}/divar/devar/skills/**)"
      "Read(/${config.home.homeDirectory}/.cache/devar/repos/**)"
    ];
  };

  cavemanMarketplace = lib.optionalAttrs cfg.enableCaveman {
    caveman = {
      source = {
        source = "github";
        repo = "JuliusBrussee/caveman";
      };
    };
  };

  cavemanPlugin = lib.optionalAttrs cfg.enableCaveman {
    "caveman@caveman" = true;
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
    enabledPlugins = {
      "figma@claude-plugins-official" = true;
    }
    // devarPlugin;
    theme = "dark";
    outputStyle = "concise";
    skipAutoPermissionPrompt = true;
    hooks = {
      SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = "${claudeIpGuard}/bin/claude-ip-guard";
              timeout = 33;
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
              timeout = 33;
            }
          ];
        }
      ];
    };
  };

  glmSettings = workSettings // {
    statusLine = {
      type = "command";
      command = "${glmStatusLine}/bin/glm-claude-statusline";
    };
  };

  gapSettings = {
    theme = "dark";
  };

  deepseekSettings = {
    theme = "dark";
    extraKnownMarketplaces = devarMarketplace;
    enabledPlugins = devarPlugin;
    permissions = devarPermissions;
  };

  normalSettings = {
    theme = "dark";
    extraKnownMarketplaces = devarMarketplace // cavemanMarketplace;
    enabledPlugins = devarPlugin // cavemanPlugin;
    permissions = devarPermissions;
    hooks = {
      SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = "${claudeIpGuard}/bin/claude-ip-guard";
              timeout = 33;
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
              timeout = 33;
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
    ++ lib.optional cfg.enableDeepseek (
      pickerEntry "deepseek" "deepseek-claude" "DeepSeek, native Anthropic API" deepseekClaude
    )
    ++ lib.optional cfg.enableWork (pickerEntry "work" "work-claude" "Divar work, xhigh" claudeWork)
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
    enableDeepseek = lib.mkEnableOption ''
      the deepseek-claude variant: routes through DeepSeek's native
      Anthropic-compatible endpoint (https://api.deepseek.com/anthropic).
      Reads the API key from ~/deepseek-key
    '';
    enableWork = lib.mkEnableOption "Install the work-claude variant (work-host only)";
    enableLocal = lib.mkEnableOption "Install the local-claude variant (LiteLLM -> local llama-swap model)";
    enableNormal = lib.mkEnableOption ''
      the normal-claude variant: vanilla Anthropic-direct claude wrapped with
      a fail-closed Iran IP guard with multiple country lookup providers. A
      failure across all providers blocks the launch — this is deliberate,
      since connecting to Anthropic from a sanctioned region risks the account
    '';
    enableDevar = lib.mkEnableOption ''
      the Divar `devar` plugin in the work variant: the directory-sourced
      "divar" marketplace (~/divar/devar) and the `devar@divar` plugin entry.
      Set by modules/work.nix (isWork) so it lands only on the work laptop —
      the host that has the ~/divar/devar checkout. Other work-claude hosts
      (e.g. g14) get the variant without devar
    '';
    enableCaveman = lib.mkEnableOption ''
      the caveman plugin (JuliusBrussee/caveman, github.com/juliusbrussee/caveman)
      in the normal-claude variant: a "talk like caveman" output-compression
      skill that trims reply tokens (fragments, minimal filler) while keeping
      code/commands/errors byte-for-byte. Registered as a github plugin
      marketplace non-interactively, same mechanism as enableDevar; try it via
      the /caveman, /caveman-stats and /caveman-compress slash commands it adds
    '';

    glmPrices = lib.mkOption {
      type = lib.types.submodule {
        options = {
          input = lib.mkOption {
            type = lib.types.float;
            default = 1.40;
            description = "USD per 1M non-cache input tokens for the glm-5.2 endpoint.";
          };
          output = lib.mkOption {
            type = lib.types.float;
            default = 4.40;
            description = "USD per 1M output tokens.";
          };
          cacheRead = lib.mkOption {
            type = lib.types.float;
            default = 0.26;
            description = "USD per 1M cache-read input tokens.";
          };
          cacheCreate = lib.mkOption {
            type = lib.types.float;
            default = 1.40;
            description = "USD per 1M cache-creation input tokens.";
          };
        };
      };
      default = { };
      description = ''
        Per-1M-token USD prices for the glm-5.2 (raytone) endpoint, consumed by
        the `glm-usage` tracker and its statusline week/month cost. Override
        per-host if your plan's rates differ.
      '';
    };

    glmBillingDay = lib.mkOption {
      type = lib.types.ints.between 1 31;
      default = 5;
      description = ''
        Day of month the glm-5.2 billing cycle resets. The statusline's "mo"
        window runs from this day to the day before next month's same day
        (default the 5th).
      '';
    };

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
        description = "Per-plugin overrides for the work-claude variant.";
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
      home.packages = [ glmUsage ];
      home.file.".config/glm-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" glmSettings)
      );
      home.file.".config/glm-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableDeepseek {
      home.packages = [ deepseekClaude ];
      home.file.".config/deepseek-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" deepseekSettings)
      );
      home.file.".config/deepseek-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
      home.file.".config/work-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" workSettings)
      );
      home.file.".config/work-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf (cfg.enableWork || cfg.enableGlm || cfg.enableNormal || cfg.enableDeepseek) {
      home.file.${workMcpConfigRel}.text = builtins.toJSON workMcpServers;
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
    (lib.mkIf
      (cfg.enable || cfg.enableWork || cfg.enableLocal || cfg.enableNormal || cfg.enableDeepseek)
      {
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
              ++ lib.optional cfg.enableDeepseek ".config/deepseek-claude"
              ++ lib.optional cfg.enableWork ".config/work-claude"
              ++ lib.optional cfg.enableLocal ".config/local-claude"
              ++ lib.optional cfg.enableNormal ".config/normal-claude"
            )
        );
      }
    )
  ];
}
