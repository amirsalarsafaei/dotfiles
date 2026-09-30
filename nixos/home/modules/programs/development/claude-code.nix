{
  config,
  lib,
  pkgs,
  secrets,
  inputs,
  ...
}:
let
  cfg = config.custom.claudeCode;

  claudeZellijAttention = pkgs.writeShellApplication {
    name = "claude-zellij-attention";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.libnotify
      pkgs.procps
      pkgs.zellij
    ];
    text = ''
      cat >/dev/null
      if [ -z "''${ZELLIJ:-}" ] || [ -z "''${ZELLIJ_PANE_ID:-}" ]; then
        exit 0
      fi

      pid=$$
      while [ "$pid" -gt 1 ]; do
        read -r pane_tty ppid < <(ps -o tty=,ppid= -p "$pid") || break
        if [ "$pane_tty" != "?" ] && [ -w "/dev/$pane_tty" ]; then
          printf '\a' >"/dev/$pane_tty" || true
          break
        fi
        pid=$ppid
      done

      tab_id=$(timeout 2 zellij action list-panes -j \
        | jq -r --argjson id "$ZELLIJ_PANE_ID" '.[] | select(.id == $id and (.is_plugin | not)) | .tab_id') || tab_id=""
      tab_active=false
      if [ -n "$tab_id" ]; then
        tab_active=$(timeout 2 zellij action list-tabs -j \
          | jq -r --argjson id "$tab_id" 'any(.[]; .tab_id == $id and .active)') || tab_active=false
      fi

      window_class=""
      if command -v hyprctl >/dev/null; then
        window_class=$(timeout 2 hyprctl activewindow -j | jq -r '.class // empty') || window_class=""
      fi

      if [ "$tab_active" = true ] && [ "$window_class" = com.mitchellh.ghostty ]; then
        exit 0
      fi

      timeout 5 notify-send --app-name "Claude Code" "Claude Code" "requires your input" || true
    '';
  };

  claudeAgentStatus = pkgs.writeShellApplication {
    name = "claude-agent-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      dir="''${XDG_RUNTIME_DIR:-/nonexistent}/${cfg.agentStatus.dir}"
      if [ ! -d "$dir" ] || [ ! -w "$dir" ]; then
        cat >/dev/null
        exit 0
      fi

      state="$dir/state.json"
      variant=$(basename "''${CLAUDE_CONFIG_DIR:-claude}")
      variant=''${variant%-claude}
      next=$(mktemp "$dir/.state.XXXXXX")
      trap 'rm -f "$next"' EXIT

      exec 9>"$dir/.lock"
      flock -w 3 9 || exit 0

      current=/dev/null
      if jq -e 'type == "object"' "$state" >/dev/null 2>&1; then
        current=$state
      fi

      jq -c \
        --argjson now "$(date +%s%3N)" \
        --arg variant "$variant" \
        --arg realm "''${CLAUDE_VARIANT_REALM:-}" \
        --arg zsession "''${ZELLIJ_SESSION_NAME:-}" \
        --arg zpane "''${ZELLIJ_PANE_ID:-}" \
        --slurpfile cur "$current" \
        -f ${./claude-agent-status.jq} >"$next"
      mv -f "$next" "$state"
    '';
  };

  agentStatusHooks = lib.optionalAttrs cfg.agentStatus.enable (
    lib.genAttrs
      [
        "SessionStart"
        "SessionEnd"
        "UserPromptSubmit"
        "PreToolUse"
        "PostToolUse"
        "PostToolUseFailure"
        "Notification"
        "SubagentStart"
        "SubagentStop"
        "PreCompact"
        "Stop"
        "StopFailure"
      ]
      (_: [
        {
          hooks = [
            {
              type = "command";
              command = lib.getExe claudeAgentStatus;
              timeout = 5;
              async = true;
            }
          ];
        }
      ])
  );

  devar = pkgs.callPackage ../../../../pkgs/devar.nix { devarSrc = inputs.devar; };

  workEffortLevel = "xhigh";

  usagePriceModel = lib.types.submodule {
    options = {
      input = lib.mkOption {
        type = lib.types.float;
        description = "USD per 1M non-cache input tokens (peak/standard rate).";
      };
      output = lib.mkOption {
        type = lib.types.float;
        description = "USD per 1M output tokens (peak/standard rate).";
      };
      cacheRead = lib.mkOption {
        type = lib.types.float;
        description = "USD per 1M cache-read input tokens (peak/standard rate).";
      };
      cacheCreate = lib.mkOption {
        type = lib.types.float;
        description = "USD per 1M cache-creation input tokens (peak/standard rate).";
      };
      inputOffpeak = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "USD per 1M non-cache input tokens during off-peak hours, if discounted.";
      };
      outputOffpeak = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "USD per 1M output tokens during off-peak hours, if discounted.";
      };
      cacheReadOffpeak = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "USD per 1M cache-read input tokens during off-peak hours, if discounted.";
      };
      cacheCreateOffpeak = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "USD per 1M cache-creation input tokens during off-peak hours, if discounted.";
      };
    };
  };

  usagePriceModelToJson =
    m:
    {
      inherit (m) input output;
      cache_read = m.cacheRead;
      cache_create = m.cacheCreate;
    }
    // lib.optionalAttrs (m.inputOffpeak != null) { input_offpeak = m.inputOffpeak; }
    // lib.optionalAttrs (m.outputOffpeak != null) { output_offpeak = m.outputOffpeak; }
    // lib.optionalAttrs (m.cacheReadOffpeak != null) { cache_read_offpeak = m.cacheReadOffpeak; }
    // lib.optionalAttrs (m.cacheCreateOffpeak != null) {
      cache_create_offpeak = m.cacheCreateOffpeak;
    };

  sandboxSecretDenyPaths = [
    "${config.home.homeDirectory}/.ssh"
    "${config.home.homeDirectory}/.gnupg/private-keys-v1.d"
    "${config.home.homeDirectory}/.gnupg/openpgp-revocs.d"
    "${config.home.homeDirectory}/.gnupg/secring.gpg"
    "${config.home.homeDirectory}/.aws"
    "${config.home.homeDirectory}/.kube"
    "${config.home.homeDirectory}/.docker"
    "${config.home.homeDirectory}/.netrc"
    "${config.home.homeDirectory}/.git-credentials"
    "${config.home.homeDirectory}/.password-store"
    "${config.home.homeDirectory}/.config/gh"
    "${config.home.homeDirectory}/.config/glab-cli"
    "${config.home.homeDirectory}/.config/gcloud"
    "${config.home.homeDirectory}/.config/sops"
    "${config.home.homeDirectory}/.config/age"
    "${config.home.homeDirectory}/.local/share/keyrings"
    "${config.home.homeDirectory}/.local/share/gcalcli"
    "${config.home.homeDirectory}/.cache/agenda-os"
    "${config.home.homeDirectory}/.mozilla"
    "${config.home.homeDirectory}/.pki"
    "${config.home.homeDirectory}/.config/chromium"
    "${config.home.homeDirectory}/.config/google-chrome"
    "${config.home.homeDirectory}/.config/BraveSoftware"
    "${config.home.homeDirectory}/.config/rclone"
    "${config.home.homeDirectory}/.cargo/credentials.toml"
    "${config.home.homeDirectory}/.pypirc"
    "${config.home.homeDirectory}/zshsecret"
    "${config.home.homeDirectory}/glm-key"
    "${config.home.homeDirectory}/deepseek-key"
    "${config.home.homeDirectory}/personal-deepseek"
    "${config.home.homeDirectory}/divar-glm"
    "${config.home.homeDirectory}/divar-deepseek"
  ];

  claudeSandbox = pkgs.writeShellApplication {
    name = "claude-sandbox";
    runtimeInputs = [
      pkgs.bubblewrap
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      export CLAUDE_SANDBOX_TARGET="${pkgs.claude-code}/bin/claude"
      export CLAUDE_SANDBOX_DENY=${lib.escapeShellArg (lib.concatStringsSep "\n" cfg.sandbox.denyPaths)}
      export CLAUDE_SANDBOX_ALLOW=${lib.escapeShellArg (lib.concatStringsSep "\n" cfg.sandbox.allowPaths)}
      export CLAUDE_SANDBOX_ENV_FILES=${lib.escapeShellArg (lib.concatStringsSep "\n" cfg.sandbox.envFiles)}
      export CLAUDE_SANDBOX_ENV_KEEP=${lib.escapeShellArg (lib.concatStringsSep "\n" cfg.sandbox.envPassthrough)}
      context_sandbox=${pkgs.writeText "claude-context-sandbox.md" cfg.context.sandbox}
      context_sandbox_net=${pkgs.writeText "claude-context-sandbox-net.md" cfg.context.sandboxNet}
      context_sandbox_fs=${pkgs.writeText "claude-context-sandbox-fs.md" cfg.context.sandboxFs}
      ${builtins.readFile ./claude-sandbox.sh}
    '';
  };

  claudeBin =
    if cfg.sandbox.enable then
      "${claudeSandbox}/bin/claude-sandbox"
    else
      "${pkgs.claude-code}/bin/claude";

  sandboxParserText = lib.optionalString cfg.sandbox.enable (
    mkBoolFlagParser {
      flag = "--no-sandbox";
      resultVar = "_claude_sandbox_off";
    }
    + mkBoolFlagParser {
      flag = "--sandbox-net";
      resultVar = "_claude_sandbox_net";
    }
    + mkBoolFlagParser {
      flag = "--sandbox-fs";
      resultVar = "_claude_sandbox_fs";
    }
    + ''
      if [ "$_claude_sandbox_off" -eq 1 ]; then
        export CLAUDE_SANDBOX_OFF=1
      fi
      if [ "$_claude_sandbox_net" -eq 1 ]; then
        export CLAUDE_SANDBOX_NET=1
      fi
      if [ "$_claude_sandbox_fs" -eq 1 ]; then
        export CLAUDE_SANDBOX_FS=1
      fi
      unset _claude_sandbox_off _claude_sandbox_net _claude_sandbox_fs
    ''
  );

  commonParserText = effortParserText + sandboxParserText;

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

  workClaudeConfigDir = "${config.home.homeDirectory}/.config/work-claude";
  glmClaudeConfigDir = "${config.home.homeDirectory}/.config/glm-claude";
  deepseekClaudeConfigDir = "${config.home.homeDirectory}/.config/deepseek-claude";
  workDivarGlmClaudeConfigDir = "${config.home.homeDirectory}/.config/work-divar-glm-claude";
  workDivarDeepseekClaudeConfigDir = "${config.home.homeDirectory}/.config/work-divar-deepseek-claude";
  personalClaudeConfigDir = "${config.home.homeDirectory}/.config/personal-claude";
  personalDeepseekClaudeConfigDir = "${config.home.homeDirectory}/.config/personal-deepseek-claude";

  workClaudeSharedDir = "${config.home.homeDirectory}/.config/work-claude-shared";
  personalClaudeSharedDir = "${config.home.homeDirectory}/.config/personal-claude-shared";

  conversationShareNames = [
    "projects"
    "history.jsonl"
  ];

  mkConversationShareFiles =
    sharedDir: variantDir:
    lib.listToAttrs (
      map (name: {
        name = "${variantDir}/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${sharedDir}/${name}";
      }) conversationShareNames
    );

  mkConversationShareMigration = sharedDir: variantDirs: ''
    _cc_shared="${sharedDir}"
    mkdir -p "$_cc_shared/projects"
    [ -f "$_cc_shared/history.jsonl" ] || : > "$_cc_shared/history.jsonl"
    for _cc_v in ${lib.concatStringsSep " " variantDirs}; do
      [ -d "$_cc_v" ] || continue
      if [ -d "$_cc_v/projects" ] && [ ! -L "$_cc_v/projects" ]; then
        if [ -z "$(ls -A "$_cc_shared/projects" 2>/dev/null)" ]; then
          if mv -T -- "$_cc_v/projects" "$_cc_shared/projects"; then
            :
          else
            printf 'claude conversation migration: mv %s/projects failed; leaving it in place\n' "$_cc_v" >&2
          fi
        elif cp -an -- "$_cc_v/projects/." "$_cc_shared/projects/"; then
          rm -rf -- "$_cc_v/projects"
        else
          printf 'claude conversation migration: failed to merge %s/projects; leaving it in place\n' "$_cc_v" >&2
        fi
      fi
      if [ -f "$_cc_v/history.jsonl" ] && [ ! -L "$_cc_v/history.jsonl" ]; then
        if cat -- "$_cc_v/history.jsonl" >> "$_cc_shared/history.jsonl"; then
          rm -f -- "$_cc_v/history.jsonl"
        else
          printf 'claude conversation migration: failed to merge %s/history.jsonl; leaving it in place\n' "$_cc_v" >&2
        fi
      fi
    done
    unset _cc_shared _cc_v
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

  chromeDevtoolsMcp = pkgs.callPackage ../../../../pkgs/chrome-devtools-mcp.nix { };
  mcpChromeBridge = pkgs.callPackage ../../../../pkgs/mcp-chrome-bridge { };

  browserMcpDirRel = ".config/claude-browser-mcp";
  secChromeMcpConfigRel = "${browserMcpDirRel}/chrome-devtools.json";
  secChromeMcpConfigPath = "${config.home.homeDirectory}/${secChromeMcpConfigRel}";
  chromeMcpConfigRel = "${browserMcpDirRel}/chrome.json";
  chromeMcpConfigPath = "${config.home.homeDirectory}/${chromeMcpConfigRel}";
  chromeNativeHostRel = ".config/google-chrome/NativeMessagingHosts/com.chromemcp.nativehost.json";
  playwrightMcpConfigRel = "${browserMcpDirRel}/playwright.json";
  playwrightMcpConfigPath = "${config.home.homeDirectory}/${playwrightMcpConfigRel}";

  chromeMcpServers = {
    mcpServers = {
      chrome = {
        type = "http";
        url = "http://127.0.0.1:12306/mcp";
      };
    };
  };

  chromeNativeHost = {
    name = "com.chromemcp.nativehost";
    description = "Node.js Host for Browser Bridge Extension";
    path = "${mcpChromeBridge}/lib/node_modules/mcp-chrome-bridge/dist/run_host.sh";
    type = "stdio";
    allowed_origins = [ "chrome-extension://hbdgbgagpkpjffpklnamcljpakneikee/" ];
  };

  secChromeMcpServers = {
    mcpServers = {
      chrome-devtools = {
        command = "${chromeDevtoolsMcp}/bin/chrome-devtools-mcp";
        args = [
          "--executablePath"
          "${pkgs.google-chrome}/bin/google-chrome-stable"
          "--no-category-performance"
          "--no-usage-statistics"
        ];
      };
    };
  };

  playwrightMcpServers = {
    mcpServers = {
      playwright = {
        command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
        args = [ "--caps=network,storage" ];
        env = {
          PLAYWRIGHT_MCP_USER_DATA_DIR = "${config.home.homeDirectory}/.cache/playwright-mcp/chrome-profile";
        };
      };
    };
  };

  nixosMcpDirRel = ".config/claude-nixos-mcp";
  nixosMcpConfigRel = "${nixosMcpDirRel}/nixos.json";
  nixosMcpConfigPath = "${config.home.homeDirectory}/${nixosMcpConfigRel}";

  nixosMcpServers = {
    mcpServers = {
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
    };
  };

  nixosMcpParserText = mkBoolFlagParser {
    flag = "--nixos";
    resultVar = "_claude_nixos";
  };

  nixosMcpArgText = ''
    if [ "$_claude_nixos" -eq 1 ]; then
      _claude_extra_args+=(--mcp-config "${nixosMcpConfigPath}")
    fi
    unset _claude_nixos
  '';

  agenticMcpParserText = mkBoolFlagParser {
    flag = "--agentic-mcps";
    resultVar = "_claude_agentic_mcps";
  };

  gitlabMcpParserText = mkBoolFlagParser {
    flag = "--gitlab-mcp";
    resultVar = "_claude_gitlab_mcp";
  };

  flagPlugins = [
    {
      flag = "--no-devar";
      plugin = "devar@divar";
      enable = false;
      desc = "disable the devar plugin for this launch";
    }
    {
      flag = "--crit";
      plugin = "crit@crit";
      enable = true;
      desc = "enable the crit review plugin (tomasz-tomczyk/crit) for this launch";
      marketplace = {
        crit = {
          source = {
            source = "github";
            repo = "tomasz-tomczyk/crit";
          };
        };
      };
    }
  ]
  ++ lib.optional cfg.enableCaveman {
    flag = "--caveman";
    plugin = "caveman@caveman";
    enable = true;
    desc = "enable caveman for this launch (--caveman=LEVEL also sets its level)";
    marketplace = cavemanMarketplace;
    env = {
      CLAUDE_CAVEMAN = "1";
    };
    levelEnv = "CAVEMAN_DEFAULT_MODE";
    levels = cavemanLevels;
  }
  ++ lib.optional cfg.planner.enable {
    flag = "--planner";
    plugin = "claude-obsidian@agricidaniel-claude-obsidian";
    enable = true;
    desc = "enable the Obsidian vault plugin and own-calendar MCP for this launch";
    marketplace = obsidianMarketplace;
    env = {
      CLAUDE_OBSIDIAN_VAULT = obsidianVaultPath;
    };
    inherit (cfg.planner) mcpConfigs;
  };

  flagPluginsZshArgs = lib.concatMapStringsSep " " (p: "'${p.flag}[${p.desc}]'") flagPlugins;

  pluginFlagsParserText =
    let
      armBody = p: ''
        _claude_plugin_flags+=("${p.plugin}=${if p.enable then "true" else "false"}")
        ${lib.optionalString (
          p ? marketplace
        ) "_claude_plugin_marketplaces+=('${builtins.toJSON p.marketplace}')"}
        ${lib.concatMapStringsSep "\n" (
          k: "_claude_plugin_env+=(${lib.escapeShellArg "${k}=${p.env.${k}}"})"
        ) (lib.attrNames (p.env or { }))}
        ${lib.concatMapStringsSep "\n" (c: "_claude_plugin_mcp+=(${lib.escapeShellArg c})") (
          p.mcpConfigs or [ ]
        )}
      '';
      levelArm = p: ''
        ${p.flag}=*)
          case "''${1#*=}" in
            ${lib.concatStringsSep " | " p.levels}) ;;
            *)
              printf '%s: unknown level "%s" for ${p.flag} (expected one of: %s)\n' \
                "''${0##*/}" "''${1#*=}" ${lib.escapeShellArg (lib.concatStringsSep " " p.levels)} >&2
              exit 2
              ;;
          esac
          ${armBody p}
          _claude_plugin_env+=("${p.levelEnv}=''${1#*=}")
          shift
          ;;
      '';
      caseArms = lib.concatMapStringsSep "\n" (
        p:
        ''
          ${p.flag})
            ${armBody p}
            shift
            ;;
        ''
        + lib.optionalString (p ? levelEnv) (levelArm p)
      ) flagPlugins;
    in
    ''
      _claude_plugin_flags=()
      _claude_plugin_marketplaces=()
      _claude_plugin_env=()
      _claude_plugin_mcp=()
      _claude_flag_rest=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
      ${caseArms}
          *)
            _claude_flag_rest+=("$1")
            shift
            ;;
        esac
      done
      set -- "''${_claude_flag_rest[@]}"
      unset _claude_flag_rest
    '';

  pluginSettingsArgText = ''
    _claude_extra_args=()
    if [ "''${#_claude_plugin_flags[@]}" -gt 0 ]; then
      _claude_settings_overlay="{}"
      for _claude_pf in "''${_claude_plugin_flags[@]}"; do
        _claude_settings_overlay=$(${pkgs.jq}/bin/jq -c \
          --arg id "''${_claude_pf%=*}" --argjson val "''${_claude_pf##*=}" \
          '.enabledPlugins[$id] = $val' <<<"$_claude_settings_overlay")
      done
      if [ "''${#_claude_plugin_marketplaces[@]}" -gt 0 ]; then
        _claude_settings_file="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
        _claude_known="{}"
        if [ -s "$_claude_settings_file" ]; then
          _claude_known=$(${pkgs.jq}/bin/jq -c '.extraKnownMarketplaces // {}' \
            "$_claude_settings_file" 2>/dev/null || printf '{}')
        fi
        for _claude_pm in "''${_claude_plugin_marketplaces[@]}"; do
          _claude_known=$(${pkgs.jq}/bin/jq -c --argjson add "$_claude_pm" \
            '. + $add' <<<"$_claude_known")
        done
        _claude_settings_overlay=$(${pkgs.jq}/bin/jq -c --argjson km "$_claude_known" \
          '.extraKnownMarketplaces = $km' <<<"$_claude_settings_overlay")
        unset _claude_settings_file _claude_known _claude_pm
      fi
      if [ "''${#_claude_plugin_env[@]}" -gt 0 ]; then
        _claude_settings_file="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
        _claude_env="{}"
        if [ -s "$_claude_settings_file" ]; then
          _claude_env=$(${pkgs.jq}/bin/jq -c '.env // {}' \
            "$_claude_settings_file" 2>/dev/null || printf '{}')
        fi
        for _claude_pe in "''${_claude_plugin_env[@]}"; do
          _claude_env=$(${pkgs.jq}/bin/jq -c \
            --arg k "''${_claude_pe%%=*}" --arg v "''${_claude_pe#*=}" \
            '.[$k] = $v' <<<"$_claude_env")
        done
        _claude_settings_overlay=$(${pkgs.jq}/bin/jq -c --argjson env "$_claude_env" \
          '.env = $env' <<<"$_claude_settings_overlay")
        unset _claude_settings_file _claude_env _claude_pe
      fi
      _claude_extra_args+=(--settings "$_claude_settings_overlay")
      unset _claude_settings_overlay _claude_pf
    fi
    for _claude_pc in "''${_claude_plugin_mcp[@]}"; do
      _claude_extra_args+=(--mcp-config "$_claude_pc")
    done
    unset _claude_plugin_flags _claude_plugin_marketplaces _claude_plugin_env _claude_plugin_mcp _claude_pc
  '';

  browserMcpParserText =
    mkBoolFlagParser {
      flag = "--chrome";
      resultVar = "_claude_chrome";
    }
    + mkBoolFlagParser {
      flag = "--sec-chrome";
      resultVar = "_claude_sec_chrome";
    }
    + mkBoolFlagParser {
      flag = "--playwright";
      resultVar = "_claude_playwright";
    };

  browserMcpArgText = ''
    _claude_extra_args+=(--no-chrome)
    if [ "$_claude_chrome" -eq 1 ]; then
      _claude_extra_args+=(--mcp-config "${chromeMcpConfigPath}")
    fi
    if [ "$_claude_sec_chrome" -eq 1 ]; then
      _claude_extra_args+=(--mcp-config "${secChromeMcpConfigPath}")
    fi
    if [ "$_claude_playwright" -eq 1 ]; then
      _claude_extra_args+=(--mcp-config "${playwrightMcpConfigPath}")
    fi
    unset _claude_chrome _claude_sec_chrome _claude_playwright
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
        command = "node";
        args = [ "${config.home.homeDirectory}/personal/godot-mcp/build/index.js" ];
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
      plugins="$dir/plugins"

      commit_json() {
        local file="$1" tmp="$2" fixes="$3"
        if [ -s "$tmp" ]; then
          mv -f "$tmp" "$file"
          printf 'heal-claude-json: re-rooted %s stale path(s) in %s\n' \
            "$(jq 'length' <<<"$fixes")" "$file" >&2
        else
          rm -f "$tmp"
        fi
      }

      known="$plugins/known_marketplaces.json"
      if [ -s "$known" ] && jq -e 'type == "object"' "$known" >/dev/null 2>&1; then
        fixes='{}'
        while IFS=$'\t' read -r name loc; do
          if [ ! -e "$loc" ] && [ -d "$plugins/marketplaces/$name" ]; then
            fixes=$(jq -c --arg k "$name" --arg v "$plugins/marketplaces/$name" '. + {($k): $v}' <<<"$fixes")
          fi
        done < <(jq -r 'to_entries[]
          | select((.value.source.source // "") != "directory")
          | [.key, (.value.installLocation // "")] | @tsv' "$known")
        if [ "$fixes" != '{}' ]; then
          tmp=$(mktemp "$known.XXXXXX")
          jq --argjson f "$fixes" \
            'with_entries(if $f[.key] then .value.installLocation = $f[.key] else . end)' \
            "$known" >"$tmp" || true
          commit_json "$known" "$tmp" "$fixes"
        fi
      fi

      installed="$plugins/installed_plugins.json"
      if [ -s "$installed" ] && jq -e '.plugins | type == "object"' "$installed" >/dev/null 2>&1; then
        fixes='{}'
        while IFS= read -r old; do
          rel="''${old#*/plugins/cache/}"
          if [ ! -e "$old" ] && [ "$rel" != "$old" ] && [ -d "$plugins/cache/$rel" ]; then
            fixes=$(jq -c --arg k "$old" --arg v "$plugins/cache/$rel" '. + {($k): $v}' <<<"$fixes")
          fi
        done < <(jq -r '.plugins[][] | .installPath // empty' "$installed")
        if [ "$fixes" != '{}' ]; then
          tmp=$(mktemp "$installed.XXXXXX")
          jq --argjson f "$fixes" \
            '.plugins |= map_values(map(if $f[.installPath // ""] then .installPath = $f[.installPath] else . end))' \
            "$installed" >"$tmp" || true
          commit_json "$installed" "$tmp" "$fixes"
        fi
      fi

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
    ${commonParserText}
    ${pluginFlagsParserText}
    ${browserMcpParserText}

    ${healClaudeState}/bin/heal-claude-json || true
    ${pluginSettingsArgText}
    ${browserMcpArgText}
    exec ${claudeBin} "''${_claude_extra_args[@]}" "$@"
  '';

  glmClaude = pkgs.writeShellApplication {
    name = "glm-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "work";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "glm-claude";
        keyFile = "glm-key";
        authVar = "ANTHROPIC_AUTH_TOKEN";
      }}
      export CLAUDE_VARIANT_NAME="glm-claude"
      export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
      export ANTHROPIC_MODEL="glm-5.3[1m]"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.3[1m]"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.3[1m]"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.3-flash[1m]"
      export CLAUDE_CODE_SUBAGENT_MODEL="glm-5.3-flash[1m]"
      export CLAUDE_CONFIG_DIR="${glmClaudeConfigDir}"
      export CLAUDE_CODE_EFFORT_DEFAULT="${workEffortLevel}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576"
      export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"
      ${workWrapperTail}
    '';
  };

  workDivarGlmClaude = pkgs.writeShellApplication {
    name = "work-divar-glm-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "work";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "work-divar-glm-claude";
        keyFile = "divar-glm";
        authVar = "ANTHROPIC_AUTH_TOKEN";
      }}
      export CLAUDE_VARIANT_NAME="work-divar-glm-claude"
      export ANTHROPIC_BASE_URL="http://204.12.171.47:4000"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="divar-glm5.3"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="divar-glm5.3"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="divar-glm5.3"
      export CLAUDE_CONFIG_DIR="${workDivarGlmClaudeConfigDir}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="180000"
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
      export API_TIMEOUT_MS="3000000"
      ${workWrapperTail}
    '';
  };

  workDivarDeepseekClaude = pkgs.writeShellApplication {
    name = "work-divar-deepseek-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "work";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "work-divar-deepseek-claude";
        keyFile = "divar-deepseek";
        authVar = "ANTHROPIC_AUTH_TOKEN";
      }}
      export CLAUDE_VARIANT_NAME="work-divar-deepseek-claude"
      export ANTHROPIC_BASE_URL="http://204.12.171.47:4000"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="divar-deepseek"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="divar-deepseek"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="divar-deepseek"
      export CLAUDE_CONFIG_DIR="${workDivarDeepseekClaudeConfigDir}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="100000"
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
      export API_TIMEOUT_MS="3000000"
      ${workWrapperTail}
    '';
  };

  deepseekClaude = pkgs.writeShellApplication {
    name = "deepseek-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "work";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "deepseek-claude";
        keyFile = "deepseek-key";
        authVar = "ANTHROPIC_API_KEY";
      }}
      export CLAUDE_VARIANT_NAME="deepseek-claude"
      export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
      export ANTHROPIC_MODEL="deepseek-v4-pro"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-flash"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-flash"
      export ANTHROPIC_SMALL_FAST_MODEL="deepseek-flash"
      export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-flash"
      export CLAUDE_CONFIG_DIR="${deepseekClaudeConfigDir}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576"
      export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"
      ${workWrapperTail}
    '';
  };

  personalDeepseekClaude = pkgs.writeShellApplication {
    name = "personal-deepseek-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "personal";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${mkKeyAuth {
        name = "personal-deepseek-claude";
        keyFile = "personal-deepseek";
        authVar = "ANTHROPIC_API_KEY";
      }}
      export CLAUDE_VARIANT_NAME="personal-deepseek-claude"
      export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
      export ANTHROPIC_MODEL="deepseek-v4-pro"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-flash"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-flash"
      export ANTHROPIC_SMALL_FAST_MODEL="deepseek-flash"
      export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-flash"
      export CLAUDE_CONFIG_DIR="${personalDeepseekClaudeConfigDir}"
      export CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576"
      export CLAUDE_CODE_MAX_CONTEXT_TOKENS="1048576"
      ${commonParserText}
      ${pluginFlagsParserText}
      ${browserMcpParserText}
      ${nixosMcpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      ${browserMcpArgText}
      ${nixosMcpArgText}
      exec ${claudeBin} "''${_claude_extra_args[@]}" "$@"
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
    ];
    text = ''
      input=$(cat)

      jq_get() {
        printf '%s' "$input" | jq -r "$1" 2>/dev/null || printf '%s' "$2"
      }

      abbrev_path() {
        local input_path="$1" prefix="" body seg segs out i n joined
        case "$input_path" in
          /*)
            prefix="/"
            body="''${input_path#/}"
            ;;
          *) body="$input_path" ;;
        esac
        IFS='/' read -ra segs <<< "$body"
        n=''${#segs[@]}
        out=()
        for ((i = 0; i < n; i++)); do
          seg="''${segs[i]}"
          [ -z "$seg" ] && continue
          if { [ "$i" -eq 0 ] && [ "$seg" = "~" ]; } || [ "$i" -eq $((n - 1)) ]; then
            out+=("$seg")
          else
            out+=("''${seg:0:1}")
          fi
        done
        joined=$(IFS=/; printf '%s' "''${out[*]}")
        printf '%s%s' "$prefix" "$joined"
      }

      pct_bar() {
        local pct_raw="$1" pct_int filled bar i
        pct_int="''${pct_raw%%.*}"
        case "$pct_int" in *[!0-9]*) pct_int=0 ;; esac
        [ -z "$pct_int" ] && pct_int=0
        [ "$pct_int" -gt 100 ] && pct_int=100
        filled=$(( pct_int * 5 / 100 ))
        bar=""
        for ((i = 0; i < 5; i++)); do
          if [ "$i" -lt "$filled" ]; then bar="''${bar}█"; else bar="''${bar}░"; fi
        done
        printf '%s%d%%' "$bar" "$pct_int"
      }

      model=$(jq_get '.model.display_name // .model.id // ""' "")
      cwd=$(jq_get '.workspace.current_dir // .cwd // ""' "")
      transcript=$(jq_get '.transcript_path // ""' "")
      cost=$(jq_get '.cost.total_cost_usd // 0' "0")
      added=$(jq_get '.cost.total_lines_added // 0' "0")
      removed=$(jq_get '.cost.total_lines_removed // 0' "0")
      style=$(jq_get '.output_style.name // ""' "")
      exceeds=$(jq_get '.exceeds_200k_tokens // false' "false")
      five_hour_pct=$(jq_get '.rate_limits.five_hour.used_percentage // empty' "")
      seven_day_pct=$(jq_get '.rate_limits.seven_day.used_percentage // empty' "")

      short_cwd=$(abbrev_path "''${cwd/#$HOME/\~}")

      branch=""
      if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
                 || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
      fi

      now=$(date +'%H:%M %Z' 2>/dev/null || true)

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
        limit_label="1M"
      else
        limit_label="200k"
      fi
      ctx_k=$(( ctx_tokens / 1000 ))

      usage_seg=""
      [ -n "$five_hour_pct" ] && usage_seg="5h $(pct_bar "$five_hour_pct")"
      if [ -n "$seven_day_pct" ]; then
        [ -n "$usage_seg" ] && usage_seg="$usage_seg  "
        usage_seg="''${usage_seg}wk $(pct_bar "$seven_day_pct")"
      fi

      parts=()
      [ -n "$model" ]     && parts+=("[$model]")
      [ -n "$short_cwd" ] && parts+=("$short_cwd")
      [ -n "$branch" ]    && parts+=("($branch)")
      [ -n "$usage_seg" ] && parts+=("$usage_seg")
      parts+=("ctx ''${ctx_k}k/''${limit_label}")
      if [ "$(printf '%s' "$input" | jq -r '(.cost.total_cost_usd // 0) > 0' 2>/dev/null)" = "true" ]; then
        parts+=("$(printf '$%.2f' "$cost")")
      fi
      if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
        parts+=("+$added -$removed")
      fi
      [ -n "$style" ] && [ "$style" != "default" ] && parts+=("$style")

      cfg_dir="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      caveman_level=""
      caveman_suffix=""
      if [ "''${CLAUDE_CAVEMAN:-}" = 1 ]; then
        [ -f "$cfg_dir/.caveman-active" ] && caveman_level=$(cat "$cfg_dir/.caveman-active" 2>/dev/null || true)
        [ -f "$cfg_dir/.caveman-statusline-suffix" ] && caveman_suffix=$(cat "$cfg_dir/.caveman-statusline-suffix" 2>/dev/null || true)
      fi
      if [ -n "$caveman_level" ] && [ "$caveman_level" != "off" ]; then
        parts+=("🦴 $caveman_level")
      fi
      [ -n "$caveman_suffix" ] && parts+=("$caveman_suffix")

      [ -n "$now" ] && parts+=("$now")

      result=""
      for p in "''${parts[@]}"; do
        if [ -z "$result" ]; then result="$p"; else result="$result | $p"; fi
      done
      printf '%s\n' "$result"
    '';
  };

  glmPricesJson = builtins.toJSON (lib.mapAttrs (_: usagePriceModelToJson) cfg.glmPrices);
  deepseekPricesJson = builtins.toJSON (lib.mapAttrs (_: usagePriceModelToJson) cfg.deepseekPrices);

  glmUsage = pkgs.writeShellApplication {
    name = "glm-usage";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      if [ -z "''${GLM_PRICES:-}" ]; then
        export GLM_PRICES=${lib.escapeShellArg glmPricesJson}
      fi
      export GLM_BILLING_DAY="''${GLM_BILLING_DAY-${toString cfg.glmBillingDay}}"
      exec ${pkgs.python3}/bin/python3 ${./usage-tracker.py} GLM "$@"
    '';
  };

  deepseekUsage = pkgs.writeShellApplication {
    name = "deepseek-usage";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      if [ -z "''${DEEPSEEK_PRICES:-}" ]; then
        export DEEPSEEK_PRICES=${lib.escapeShellArg deepseekPricesJson}
      fi
      if [ -z "''${DEEPSEEK_PEAK_UTC_HOURS:-}" ]; then
        export DEEPSEEK_PEAK_UTC_HOURS=${lib.escapeShellArg cfg.deepseekPeakUtcHours}
      fi
      if [ -z "''${DEEPSEEK_PEAK_WEEKDAYS:-}" ]; then
        export DEEPSEEK_PEAK_WEEKDAYS=${lib.escapeShellArg cfg.deepseekPeakWeekdays}
      fi
      export DEEPSEEK_BILLING_DAY="''${DEEPSEEK_BILLING_DAY-${toString cfg.deepseekBillingDay}}"
      exec ${pkgs.python3}/bin/python3 ${./usage-tracker.py} DEEPSEEK "$@"
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

  deepseekStatusLine = pkgs.writeShellApplication {
    name = "deepseek-claude-statusline";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      input=$(cat)
      base=$(${claudeStatusLine}/bin/claude-statusline <<<"$input" 2>/dev/null || true)
      seg=$(${deepseekUsage}/bin/deepseek-usage statusline 2>/dev/null || true)
      if [ -n "$seg" ] && [ -n "$base" ]; then
        printf '%s | %s\n' "$base" "$seg"
      elif [ -n "$base" ]; then
        printf '%s\n' "$base"
      else
        printf 'deepseek\n'
      fi
    '';
  };

  divarPathGuardText = ''
    case "$PWD" in
      *divar*)
        case "$PWD" in
          *devar*) ;;
          *)
            printf 'personal-claude: cwd looks like a divar path (%s). Launch anyway? [y/N] ' "$PWD" >&2
            read -r _claude_divar_confirm </dev/tty || _claude_divar_confirm=""
            case "$_claude_divar_confirm" in
              y | Y | yes | YES) ;;
              *)
                printf 'personal-claude: aborted.\n' >&2
                exit 1
                ;;
            esac
            unset _claude_divar_confirm
            ;;
        esac
        ;;
    esac
  '';

  personalClaude = pkgs.writeShellApplication {
    name = "personal-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "personal";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.tzdata
    ];
    text = ''
      ${ipGuardText}
      ${divarPathGuardText}
      export CLAUDE_VARIANT_NAME="personal-claude"
      export CLAUDE_CONFIG_DIR="${personalClaudeConfigDir}"
      export CLAUDE_CODE_SUBAGENT_MODEL="sonnet"
      export TZ="Europe/Berlin"
      export TZDIR="${pkgs.tzdata}/share/zoneinfo"
      ${commonParserText}
      ${agenticMcpParserText}
      ${gitlabMcpParserText}
      ${pluginFlagsParserText}
      ${browserMcpParserText}
      ${nixosMcpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      ${browserMcpArgText}
      ${nixosMcpArgText}
      if [ "$_claude_agentic_mcps" -eq 1 ]; then
        if [ "$_claude_gitlab_mcp" -eq 1 ]; then
          exec ${claudeBin} --mcp-config ${workMcpConfigPath} "''${_claude_extra_args[@]}" "$@"
        else
          exec ${claudeBin} --mcp-config ${workMcpConfigPath} \
            --disallowedTools "mcp__${workMcpServerName}__gitlab_*" "''${_claude_extra_args[@]}" "$@"
        fi
      else
        exec ${claudeBin} "''${_claude_extra_args[@]}" "$@"
      fi
    '';
  };

  gapClaude = pkgs.writeShellApplication {
    name = "gap-claude";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export CLAUDE_VARIANT_NAME="gap-claude"
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/gap-claude"
      export ANTHROPIC_API_KEY="${secrets.gapgpt.apiKey or ""}"
      export ANTHROPIC_BASE_URL="https://api.gapgpt.app/"
      ${commonParserText}
      ${pluginFlagsParserText}
      ${browserMcpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      ${browserMcpArgText}
      exec ${claudeBin} "''${_claude_extra_args[@]}" "$@"
    '';
  };

  claudeWork = pkgs.writeShellApplication {
    name = "work-claude";
    runtimeEnv.CLAUDE_VARIANT_REALM = "work";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.tzdata
    ];
    text = ''
      ${ipGuardText}
      export CLAUDE_VARIANT_NAME="work-claude"
      export CLAUDE_CONFIG_DIR="${workClaudeConfigDir}"
      export CLAUDE_CODE_SUBAGENT_MODEL="sonnet"
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
      export CLAUDE_VARIANT_NAME="local-claude"
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/local-claude"
      export ANTHROPIC_BASE_URL="${localAnthropicBaseUrl}"
      export ANTHROPIC_AUTH_TOKEN="${localProxyKey}"
      export ANTHROPIC_MODEL="${localModel}"
      export ANTHROPIC_SMALL_FAST_MODEL="${localModelFast}"
      ${commonParserText}
      ${pluginFlagsParserText}
      ${browserMcpParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      ${browserMcpArgText}
      exec ${claudeBin} --mcp-config "${localMcpConfigPath}" "''${_claude_extra_args[@]}" "$@"
    '';
  };

  localAnthropicBaseUrl = "http://127.0.0.1:18081";
  localProxyKey = "sk-local";
  localModel = "qwen3.6-apex";
  localModelFast = "qwen3.6-apex-nothink";

  defaultPlugins = {
    "cc-skills-golang@samber" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
    "lua-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
  };

  pluginType = with lib.types; attrsOf bool;

  zellijAttentionHooks =
    let
      hook = {
        type = "command";
        command = lib.getExe claudeZellijAttention;
        timeout = 10;
        async = true;
      };
    in
    {
      Stop = [ { hooks = [ hook ]; } ];
      StopFailure = [ { hooks = [ hook ]; } ];
      Notification = [
        {
          matcher = "permission_prompt|elicitation_dialog";
          hooks = [ hook ];
        }
      ];
    };

  ntfyHooks = lib.optionalAttrs config.custom.ntfy.enableClaudeHook (
    lib.genAttrs
      [
        "Stop"
        "StopFailure"
        "Notification"
      ]
      (_: [
        {
          hooks = [
            {
              type = "command";
              command = lib.getExe config.custom.ntfy.claudeHookPackage;
              timeout = 10;
              async = true;
            }
          ];
        }
      ])
  );

  mkSettings =
    variant: name: base:
    let
      plugins = cfg.plugins.default // cfg.plugins.${variant};
      cavemanMode = cfg.cavemanMode.${name};
      caveman = cfg.enableCaveman && cavemanMode != null;
      marketplaces = samberMarketplace // lib.optionalAttrs caveman cavemanMarketplace;
      env = {
        CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
      }
      // lib.optionalAttrs caveman {
        CLAUDE_CAVEMAN = "1";
        CAVEMAN_DEFAULT_MODE = cavemanMode;
      };
    in
    {
      statusLine = {
        type = "command";
        command = "${claudeStatusLine}/bin/claude-statusline";
      };
    }
    // base
    // lib.optionalAttrs (plugins != { } || base ? enabledPlugins || caveman) {
      enabledPlugins = (base.enabledPlugins or { }) // lib.optionalAttrs caveman cavemanPlugin // plugins;
    }
    // lib.optionalAttrs (marketplaces != { }) {
      extraKnownMarketplaces = (base.extraKnownMarketplaces or { }) // marketplaces;
    }
    // lib.optionalAttrs (env != { }) {
      env = (base.env or { }) // env;
    }
    // {
      hooks = lib.zipAttrsWith (_: lib.concatLists) [
        zellijAttentionHooks
        ntfyHooks
        agentStatusHooks
        (base.hooks or { })
      ];
      permissions = (base.permissions or { }) // {
        deny = (base.permissions.deny or [ ]) ++ [ "Bash(git push:*)" ];
      };
      sandbox = {
        denyRead = sandboxSecretDenyPaths;
        denyWrite = sandboxSecretDenyPaths;
      }
      // (base.sandbox or { });
    };

  localSettings = {
    autoCompactEnabled = true;
    env = {
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "131072";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
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
    extraKnownMarketplaces = astGrepMarketplace;
    enabledPlugins = astGrepPlugin;
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

  devarSkillUsageHooks = lib.optionalAttrs cfg.enableDevar {
    PostToolUse = [
      {
        matcher = "Skill";
        hooks = [
          {
            type = "command";
            command = ''
              skill=$(${pkgs.jq}/bin/jq -er '.skill_name // empty' 2>/dev/null) || exit 0
              if [ -n "$skill" ]; then
                ${devar}/bin/devar usage record skill "$skill" || true
              fi
              exit 0
            '';
          }
        ];
      }
    ];
  };

  mkGithubMarketplace = repo: {
    source = {
      source = "github";
      inherit repo;
    };
  };

  samberMarketplace = {
    samber = {
      source = {
        source = "directory";
        path = "${samberMarketplaceDir}";
      };
    };
  };

  samberMarketplaceDir = pkgs.runCommand "samber-claude-marketplace" { } ''
    mkdir -p $out/.claude-plugin
    cp -r ${inputs.samber-go-skills} $out/cc-skills-golang
    cp ${
      pkgs.writeText "samber-marketplace.json" (
        builtins.toJSON {
          name = "samber";
          owner.name = "Samuel Berthe";
          plugins = [
            {
              name = "cc-skills-golang";
              source = "./cc-skills-golang";
            }
          ];
        }
      )
    } $out/.claude-plugin/marketplace.json
  '';

  cavemanLevels = [
    "off"
    "lite"
    "full"
    "ultra"
    "wenyan-lite"
    "wenyan"
    "wenyan-full"
    "wenyan-ultra"
  ];

  cavemanMarketplace = {
    caveman = mkGithubMarketplace "JuliusBrussee/caveman";
  };

  cavemanPlugin = {
    "caveman@caveman" = true;
  };

  astGrepMarketplace = {
    "ast-grep-marketplace" = mkGithubMarketplace "ast-grep/agent-skill";
  };

  astGrepPlugin = {
    "ast-grep@ast-grep-marketplace" = true;
  };

  obsidianMarketplace = {
    "agricidaniel-claude-obsidian" = mkGithubMarketplace "AgriciDaniel/claude-obsidian";
  };

  obsidianVaultPath = "${config.home.homeDirectory}/Documents/amirsalar-vault";

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
    extraKnownMarketplaces = devarMarketplace // astGrepMarketplace;
    enabledPlugins = { } // devarPlugin // astGrepPlugin;
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
    }
    // devarSkillUsageHooks;
  };

  glmSettings = workSettings // {
    statusLine = {
      type = "command";
      command = "${glmStatusLine}/bin/glm-claude-statusline";
    };
  };

  gapSettings = {
    theme = "dark";
    extraKnownMarketplaces = astGrepMarketplace;
    enabledPlugins = astGrepPlugin;
  };

  deepseekSettings = {
    theme = "dark";
    env = {
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    };
    extraKnownMarketplaces = devarMarketplace // astGrepMarketplace;
    enabledPlugins = devarPlugin // astGrepPlugin;
    permissions = devarPermissions;
    statusLine = {
      type = "command";
      command = "${deepseekStatusLine}/bin/deepseek-claude-statusline";
    };
  };

  personalDeepseekSettings = {
    theme = "dark";
    env = {
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    };
    extraKnownMarketplaces = astGrepMarketplace;
    enabledPlugins = astGrepPlugin;
    statusLine = {
      type = "command";
      command = "${deepseekStatusLine}/bin/deepseek-claude-statusline";
    };
  };

  personalSettings = {
    theme = "dark";
    extraKnownMarketplaces = devarMarketplace // astGrepMarketplace;
    enabledPlugins = devarPlugin // astGrepPlugin;
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
    }
    // devarSkillUsageHooks;
  };

  withOverrides =
    base:
    base
    // lib.optionalAttrs (cfg.skillOverrides != { }) {
      skillOverrides = cfg.skillOverrides;
    };

  nixManagedNote = cfg.context.base;

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
    ++ lib.optional cfg.enableGlm (pickerEntry "glm" "glm-claude" "GLM via z.ai" glmClaude)
    ++ lib.optional cfg.enableDeepseek (
      pickerEntry "deepseek" "deepseek-claude" "DeepSeek, native Anthropic API" deepseekClaude
    )
    ++ lib.optional cfg.enableWorkDivarGlm (
      pickerEntry "work-divar-glm" "work-divar-glm-claude" "Divar work, divar-glm5.3 gateway"
        workDivarGlmClaude
    )
    ++ lib.optional cfg.enableWorkDivarDeepseek (
      pickerEntry "work-divar-deepseek" "work-divar-deepseek-claude" "Divar work, divar-deepseek gateway"
        workDivarDeepseekClaude
    )
    ++ lib.optional cfg.enablePersonalDeepseek (
      pickerEntry "personal-deepseek" "personal-deepseek-claude" "DeepSeek, personal key"
        personalDeepseekClaude
    )
    ++ lib.optional cfg.enableWork (pickerEntry "work" "work-claude" "Divar work, xhigh" claudeWork)
    ++ lib.optional cfg.enablePersonal (
      pickerEntry "personal" "personal-claude" "Anthropic direct, IP-guarded" personalClaude
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
    enableWorkDivarGlm = lib.mkEnableOption ''
      the work-divar-glm-claude variant: work group, routed through the Divar
      LiteLLM gateway (divar-glm5.3). Reads the token from ~/divar-glm
    '';
    enableWorkDivarDeepseek = lib.mkEnableOption ''
      the work-divar-deepseek-claude variant: work group, routed through the
      Divar LiteLLM gateway (divar-deepseek). Reads the token from
      ~/divar-deepseek
    '';
    enablePersonalDeepseek = lib.mkEnableOption ''
      the personal-deepseek-claude variant: same DeepSeek native
      Anthropic-compatible endpoint as deepseek-claude, but for personal
      (non-work) use — its own config dir and no work MCP config / devar
      plugin. Reads the API key from ~/personal-deepseek
    '';
    enableWork = lib.mkEnableOption "Install the work-claude variant (work-host only)";
    enableLocal = lib.mkEnableOption "Install the local-claude variant (LiteLLM -> local llama-swap model)";
    enablePersonal = lib.mkEnableOption ''
      the personal-claude variant: vanilla Anthropic-direct claude wrapped
      with a fail-closed Iran IP guard with multiple country lookup
      providers. A failure across all providers blocks the launch — this is
      deliberate, since connecting to Anthropic from a sanctioned region
      risks the account
    '';
    enableDevar = lib.mkEnableOption ''
      the Divar `devar` plugin in the work variant: the directory-sourced
      "divar" marketplace (~/divar/devar) and the `devar@divar` plugin entry.
      Set by modules/work.nix (isWork) so it lands only on the work laptop —
      the host that has the ~/divar/devar checkout. Other work-claude hosts
      (e.g. g14) get the variant without devar
    '';
    enableCaveman = lib.mkEnableOption ''
      the caveman plugin (JuliusBrussee/caveman, github.com/juliusbrussee/caveman),
      a "talk like caveman" output-compression
      skill that trims reply tokens (fragments, minimal filler) while keeping
      code/commands/errors byte-for-byte. Registered as a github plugin
      marketplace non-interactively, same mechanism as enableDevar; try it via
      the /caveman, /caveman-stats and /caveman-compress slash commands it adds.
      Which variants load it, and at what level, is cavemanMode; every variant
      also accepts --caveman[=LEVEL] to load it for one launch
    '';

    cavemanMode =
      let
        mkMode =
          name: default:
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum cavemanLevels);
            inherit default;
            example = "lite";
            description = ''
              Caveman level ${name} starts in (exported as CAVEMAN_DEFAULT_MODE).
              null leaves the plugin unloaded, so it costs no context until a
              launch passes --caveman (level from ~/.config/caveman/config.json,
              else full) or --caveman=LEVEL. "off" loads it silent.
              /caveman LEVEL still switches mid-session.
            '';
          };
      in
      {
        personal = mkMode "personal-claude" "full";
        work = mkMode "work-claude" "full";
        glm = mkMode "glm-claude" null;
        deepseek = mkMode "deepseek-claude" null;
        workDivarGlm = mkMode "work-divar-glm-claude" null;
        workDivarDeepseek = mkMode "work-divar-deepseek-claude" null;
        personalDeepseek = mkMode "personal-deepseek-claude" null;
        gap = mkMode "gap-claude" null;
        local = mkMode "local-claude" null;
      };
    agentStatus = {
      enable = lib.mkEnableOption ''
        live session status for the desktop: async hooks in every variant
        record each session's title, project, realm (the wrapper's
        CLAUDE_VARIANT_REALM: work or personal), zellij session and pane,
        permission mode, state (working, waiting, idle, error) and current
        tool into
        $XDG_RUNTIME_DIR/<agentStatus.dir>/state.json, which the Quickshell
        wallpaper renders. The directory is created by a user tmpfiles rule
        before any sandbox starts, because the bubblewrap sandbox binds the
        runtime directory child by child and would hide a new top-level file
      '';

      dir = lib.mkOption {
        type = lib.types.str;
        default = "claude-agents";
        description = "Directory name under $XDG_RUNTIME_DIR that holds state.json.";
      };
    };

    planner = {
      enable = lib.mkEnableOption ''
        the --planner launch flag for self and time management, accepted by
        every variant including the work ones. It loads the claude-obsidian
        plugin (github.com/AgriciDaniel/claude-obsidian) with
        CLAUDE_OBSIDIAN_VAULT pointed at ~/Documents/amirsalar-vault, and
        attaches every `planner.mcpConfigs` entry, such as the agenda module's
        own-calendar Google Calendar MCP server. Nothing loads without the
        flag, so an unflagged launch pays no context for either. Adopt the
        vault once with /claude-obsidian:wiki from a --planner launch
      '';

      mcpConfigs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          MCP config files a --planner launch passes as `--mcp-config`.
          Feature modules that serve a planner MCP server append theirs.
        '';
      };
    };

    context = {
      base = lib.mkOption {
        type = lib.types.lines;
        default = ''
          # Environment

          This machine is NixOS, built from a flake at ~/personal/dotfiles/nixos. The Claude Code
          config (settings.json, this CLAUDE.md, hooks, plugins) is generated by
          home/modules/programs/development/claude-code.nix in that flake: files in the config
          directory are read-only Nix store symlinks, so edits to them do not persist. Change the
          Nix module and let the user rebuild; never run nixos-rebuild or home-manager switch
          yourself.

          The system does not follow normal FHS conventions: there is no /usr/lib, /usr/include or
          /usr/local, /bin holds only sh, and binaries live in /nix/store and reach PATH through
          profiles. Do not hardcode FHS paths or install packages globally; load the
          nix-environment skill when a tool or library is missing.

          For ad-hoc Python (scripts, data inspection, trying models) outside any project, use the
          reusable dev shells instead of system Python or a project-local venv:
          `nix develop dev#python -c python script.py`, or `dev#python-data` for Jupyter and
          scikit-learn. Each activates a persistent writable venv under
          ''${XDG_STATE_HOME:-~/.local/state}/nix-dev/ that already has numpy, pandas, scipy,
          matplotlib, requests, PDF and Office libraries; add more (torch, transformers, ...) with
          `nix develop dev#python -c bash -c 'uv pip install --python "$VIRTUAL_ENV/bin/python" pkg'`.
          `nix develop dev#rust` is the Rust equivalent. Never use pip --user,
          --break-system-packages, or `uv sync` against that shared venv. Inside a project,
          use that project's own shell and lockfile instead.

          ~/divar holds work projects and their configuration; ~/personal holds personal projects,
          including this dotfiles flake. Keep the two apart: do not carry work code, credentials or
          context into personal repos, or the reverse.

          `git push` is denied by permission rules in every variant. Commit locally when asked and
          leave pushing, and opening pull requests, to the user.
        '';
        description = ''
          Always-present part of every variant's CLAUDE.md. The per-variant
          extras (the local variant's MCP note) are appended after it.
        '';
      };

      sandbox = lib.mkOption {
        type = lib.types.lines;
        default = ''
          ## Sandbox

          This session runs inside a bubblewrap sandbox. The filesystem is visible, but credential
          paths are masked: ~/.ssh, the SSH agent socket, ~/.config/gh, ~/.config/glab-cli,
          ~/.kube, ~/.aws, ~/.docker, cloud CLI configs and keyrings. Consequences:

          - Git over SSH cannot authenticate, so `git push`, `git pull` and `git fetch` against SSH
            remotes fail. Do not try to work around it; ask the user to run them.
          - Signed commits work: GPG signing goes through the host gpg-agent, which holds the keys.
            If the passphrase is not cached, pinentry prompts the user.
          - gh, glab, kubectl, aws and docker find no credentials.
          - PID, IPC and UTS namespaces are private, so host processes are invisible.
        '';
        description = ''
          Appended to CLAUDE.md only for sandboxed launches. The sandbox
          wrapper renders it at launch and bind-mounts the result over
          CLAUDE.md inside the mount namespace, so a `--no-sandbox` launch
          reads the base file without it.
        '';
      };

      sandboxNet = lib.mkOption {
        type = lib.types.lines;
        default = ''
          - The network namespace is unshared (`--sandbox-net`): there is no network access at all.
        '';
        description = "Appended after `sandbox` for `--sandbox-net` launches.";
      };

      sandboxFs = lib.mkOption {
        type = lib.types.lines;
        default = ''
          - The home directory is a tmpfs (`--sandbox-fs`): only the working directory, the Claude
            config directory and a few allowlisted paths (~/.cache, git config, ~/.local/share) exist
            under $HOME.
        '';
        description = "Appended after `sandbox` for `--sandbox-fs` launches.";
      };
    };

    sandbox = {
      enable = lib.mkEnableOption ''
        launching every claude variant inside a bubblewrap mount namespace
        (home/modules/programs/development/claude-sandbox.sh). The whole
        filesystem stays visible and every binary stays runnable — only
        `sandbox.denyPaths` are masked, so a `kubectl`, `git push` or `aws`
        run by the agent finds no credentials. The PID, IPC and UTS namespaces
        are unshared, so the agent cannot see, signal or ptrace processes
        outside its own tree. $SSH_AUTH_SOCK is unset and the
        agent socket masked too, so git over SSH cannot authenticate at all.
        Network is shared by default. Three per-launch flags every wrapper
        accepts: `--no-sandbox` skips bwrap entirely, `--sandbox-net` unshares
        the network namespace (kills the Anthropic API too, so it only makes
        sense with a local endpoint), and `--sandbox-fs` drops the home
        directory to a tmpfs holding only $PWD, CLAUDE_CONFIG_DIR and
        `sandbox.allowPaths`
      '';

      denyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = sandboxSecretDenyPaths;
        description = ''
          Absolute paths the sandbox masks: directories with an empty tmpfs,
          files with /dev/null. Paths outside the home directory are instead
          left out of the mount tree entirely, their parent bound
          child-by-child. $SSH_AUTH_SOCK and every entry of $KUBECONFIG are
          added at launch.
        '';
      };

      allowPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "${config.home.homeDirectory}/.cache"
          "${config.home.homeDirectory}/.gitconfig"
          "${config.home.homeDirectory}/.config/git"
          "${config.home.homeDirectory}/.local/share"
          workClaudeSharedDir
          personalClaudeSharedDir
        ];
        description = ''
          Extra paths bound into the sandbox under `--sandbox-fs`, on top of
          $PWD and CLAUDE_CONFIG_DIR. Ignored without that flag, where the
          whole filesystem minus `denyPaths` is already bound.
        '';
      };

      envFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "${config.home.homeDirectory}/zshsecret" ];
        description = ''
          Shell files scanned at launch for `export NAME` lines. Every name
          found is unset inside the sandbox unless listed in
          `sandbox.envPassthrough`.
        '';
      };

      envPassthrough = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = secrets.claudeSandbox.envPassthrough or [ ];
        description = ''
          Variable names exported by `sandbox.envFiles` that stay visible
          inside the sandbox. Sourced from the git-crypted secrets so the
          names stay out of the public repository.
        '';
      };
    };

    glmPrices = lib.mkOption {
      type = lib.types.attrsOf usagePriceModel;
      default = {
        "glm-5.3" = {
          input = 1.40;
          output = 4.40;
          cacheRead = 0.26;
          cacheCreate = 1.40;
        };
        "glm-5.3-flash" = {
          input = 0.15;
          output = 0.50;
          cacheRead = 0.03;
          cacheCreate = 0.15;
        };
      };
      description = ''
        Per-model, per-1M-token USD prices for the z.ai GLM endpoint (docs.z.ai
        pricing), consumed by `usage-tracker` and its statusline week/month
        cost. Keyed by the model id a turn's transcript records — glm-5.3 is
        the main model, glm-5.3-flash backs the Haiku/subagent slot (see
        glmClaude's ANTHROPIC_DEFAULT_HAIKU_MODEL). A turn's model is matched
        against the longest key it starts with. Override per-host if your
        plan's rates differ.
      '';
    };

    glmBillingDay = lib.mkOption {
      type = lib.types.ints.between 1 31;
      default = 5;
      description = ''
        Day of month the glm-5.3 billing cycle resets. The statusline's "mo"
        window runs from this day to the day before next month's same day
        (default the 5th).
      '';
    };

    deepseekPrices = lib.mkOption {
      type = lib.types.attrsOf usagePriceModel;
      default = {
        "deepseek-v4-pro" = {
          input = 1.32;
          output = 3.96;
          cacheRead = 0.044;
          cacheCreate = 1.32;
          inputOffpeak = 0.66;
          outputOffpeak = 1.98;
          cacheReadOffpeak = 0.022;
          cacheCreateOffpeak = 0.66;
        };
        "deepseek-flash" = {
          input = 0.30;
          output = 1.20;
          cacheRead = 0.006;
          cacheCreate = 0.30;
          inputOffpeak = 0.15;
          outputOffpeak = 0.60;
          cacheReadOffpeak = 0.003;
          cacheCreateOffpeak = 0.15;
        };
      };
      description = ''
        Per-model, per-1M-token USD prices for the DeepSeek platform
        (api-docs.deepseek.com pricing), consumed by `usage-tracker` and its
        statusline week/month cost. Keyed by the model id a turn's transcript
        records — deepseek-v4-pro backs the deepseek-claude/personal-deepseek-
        claude Opus/Sonnet slots, deepseek-flash backs Haiku/subagent. The
        "peak" fields (input/output/cacheRead/cacheCreate) are the standard
        rate; the "Offpeak" fields are DeepSeek's discounted off-peak rate,
        applied by `deepseekPeakUtcHours`/`deepseekPeakWeekdays`. Override
        per-host if DeepSeek's published rates change.
      '';
    };

    deepseekPeakUtcHours = lib.mkOption {
      type = lib.types.str;
      default = "1-4,6-10";
      description = ''
        Comma-separated UTC hour ranges (half-open, e.g. "1-4,6-10") during
        which DeepSeek bills its standard (peak) rate; every other hour uses
        each model's *Offpeak price. Empty string disables the peak/off-peak
        split and always bills the standard rate.
      '';
    };

    deepseekPeakWeekdays = lib.mkOption {
      type = lib.types.str;
      default = "0-4";
      description = ''
        Comma-separated weekday range that `deepseekPeakUtcHours` applies on,
        Monday = 0 .. Sunday = 6 (default Mon-Fri; weekends are always
        off-peak). Only meaningful when deepseekPeakUtcHours is non-empty.
      '';
    };

    deepseekBillingDay = lib.mkOption {
      type = lib.types.ints.between 1 31;
      default = 1;
      description = ''
        Day of month the statusline's DeepSeek "mo" window resets. DeepSeek is
        prepaid (no subscription cycle), so this just picks a display window
        — default the 1st (calendar month).
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

      personal = lib.mkOption {
        type = pluginType;
        default = { };
        description = "Per-plugin overrides for the personal-claude variant.";
      };

      personalDeepseek = lib.mkOption {
        type = pluginType;
        default = { };
        description = "Per-plugin overrides for the personal-deepseek-claude variant.";
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

    flagPluginsZshArgs = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      default = flagPluginsZshArgs;
      description = ''
        Generated zsh `_arguments` fragment (one `'--flag[desc]'` per entry in
        `flagPlugins`) for the CLI plugin-toggle flags every claude variant
        wrapper accepts (e.g. `--crit`, `--no-devar`). Consumed by
        home/modules/shell/zsh/functions.nix so a new flagPlugins entry gets
        shell completion automatically, no separate edit needed.
      '';
    };
  };

  config = lib.mkMerge [
    {
      home.packages = [ pkgs.crit ];
    }
    (lib.mkIf cfg.agentStatus.enable {
      systemd.user.tmpfiles.rules = [
        "d %t/${cfg.agentStatus.dir} 0700 - - -"
        "f %t/${cfg.agentStatus.dir}/state.json 0600 - - - {}"
      ];
    })
    (lib.mkIf cfg.enable {
      home.packages = [
        claudePicker
        gapClaude
      ]
      ++ lib.optional cfg.enableGlm glmClaude;
      home.file.".config/gap-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "gap" "gap" gapSettings)
      );
      home.file.".config/gap-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableGlm {
      home.packages = [ glmUsage ];
      home.file.".config/glm-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" "glm" glmSettings)
      );
      home.file.".config/glm-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableDeepseek {
      home.packages = [ deepseekClaude ];
      home.file.".config/deepseek-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" "deepseek" deepseekSettings)
      );
      home.file.".config/deepseek-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWorkDivarGlm {
      home.packages = [ workDivarGlmClaude ];
      home.file.".config/work-divar-glm-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" "workDivarGlm" workSettings)
      );
      home.file.".config/work-divar-glm-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWorkDivarDeepseek {
      home.packages = [ workDivarDeepseekClaude ];
      home.file.".config/work-divar-deepseek-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" "workDivarDeepseek" workSettings)
      );
      home.file.".config/work-divar-deepseek-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
      home.file.".config/work-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" "work" workSettings)
      );
      home.file.".config/work-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf
      (
        cfg.enableWork
        || cfg.enableGlm
        || cfg.enablePersonal
        || cfg.enableDeepseek
        || cfg.enableWorkDivarGlm
        || cfg.enableWorkDivarDeepseek
      )
      {
        home.file.${workMcpConfigRel}.text = builtins.toJSON workMcpServers;
      }
    )
    (lib.mkIf
      (
        cfg.enableWork
        || cfg.enableGlm
        || cfg.enableDeepseek
        || cfg.enableWorkDivarGlm
        || cfg.enableWorkDivarDeepseek
      )
      {
        home.file =
          (lib.optionalAttrs cfg.enableWork (
            mkConversationShareFiles workClaudeSharedDir ".config/work-claude"
          ))
          // (lib.optionalAttrs cfg.enableGlm (
            mkConversationShareFiles workClaudeSharedDir ".config/glm-claude"
          ))
          // (lib.optionalAttrs cfg.enableDeepseek (
            mkConversationShareFiles workClaudeSharedDir ".config/deepseek-claude"
          ))
          // (lib.optionalAttrs cfg.enableWorkDivarGlm (
            mkConversationShareFiles workClaudeSharedDir ".config/work-divar-glm-claude"
          ))
          // (lib.optionalAttrs cfg.enableWorkDivarDeepseek (
            mkConversationShareFiles workClaudeSharedDir ".config/work-divar-deepseek-claude"
          ));
        home.activation.claudeWorkConversationMigration = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
          mkConversationShareMigration workClaudeSharedDir (
            lib.optional cfg.enableWork workClaudeConfigDir
            ++ lib.optional cfg.enableGlm glmClaudeConfigDir
            ++ lib.optional cfg.enableDeepseek deepseekClaudeConfigDir
            ++ lib.optional cfg.enableWorkDivarGlm workDivarGlmClaudeConfigDir
            ++ lib.optional cfg.enableWorkDivarDeepseek workDivarDeepseekClaudeConfigDir
          )
        );
      }
    )
    (lib.mkIf (cfg.enablePersonal || cfg.enablePersonalDeepseek) {
      home.file =
        (lib.optionalAttrs cfg.enablePersonal (
          mkConversationShareFiles personalClaudeSharedDir ".config/personal-claude"
        ))
        // (lib.optionalAttrs cfg.enablePersonalDeepseek (
          mkConversationShareFiles personalClaudeSharedDir ".config/personal-deepseek-claude"
        ));
      home.activation.claudePersonalConversationMigration =
        lib.hm.dag.entryBefore [ "checkLinkTargets" ]
          (
            mkConversationShareMigration personalClaudeSharedDir (
              lib.optional cfg.enablePersonal personalClaudeConfigDir
              ++ lib.optional cfg.enablePersonalDeepseek personalDeepseekClaudeConfigDir
            )
          );
    })
    (lib.mkIf (cfg.enablePersonal || cfg.enablePersonalDeepseek) {
      home.file.${nixosMcpConfigRel}.text = builtins.toJSON nixosMcpServers;
    })
    (lib.mkIf cfg.enablePersonalDeepseek {
      home.packages = [ personalDeepseekClaude ];
      home.file.".config/personal-deepseek-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "personalDeepseek" "personalDeepseek" personalDeepseekSettings)
      );
      home.file.".config/personal-deepseek-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableLocal {
      home.packages = [ localClaude ];
      home.file.".config/local-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "local" "local" localSettings)
      );
      home.file.".config/local-claude/CLAUDE.md".text =
        nixManagedNote
        + "Use mcp__exa__web_search_exa for web searches and mcp__exa__web_fetch_exa for webpage retrieval. The built-in WebSearch and WebFetch tools are unavailable with the local model.\n";
      home.file.${localMcpConfigRel}.text = builtins.toJSON localMcpServers;
    })
    (lib.mkIf cfg.enablePersonal {
      home.packages = [ personalClaude ];
      home.file.".config/personal-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "personal" "personal" personalSettings)
      );
      home.file.".config/personal-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf
      (
        cfg.enable
        || cfg.enableWork
        || cfg.enableLocal
        || cfg.enablePersonal
        || cfg.enableDeepseek
        || cfg.enablePersonalDeepseek
        || cfg.enableWorkDivarGlm
        || cfg.enableWorkDivarDeepseek
      )
      {
        home.file = {
          ${chromeMcpConfigRel}.text = builtins.toJSON chromeMcpServers;
          ${secChromeMcpConfigRel}.text = builtins.toJSON secChromeMcpServers;
          ${chromeNativeHostRel}.text = builtins.toJSON chromeNativeHost;
          ${playwrightMcpConfigRel}.text = builtins.toJSON playwrightMcpServers;
        };
      }
    )
    (lib.mkIf
      (
        cfg.enable
        || cfg.enableWork
        || cfg.enableLocal
        || cfg.enablePersonal
        || cfg.enableDeepseek
        || cfg.enablePersonalDeepseek
      )
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
              ++ lib.optional cfg.enableWorkDivarGlm ".config/work-divar-glm-claude"
              ++ lib.optional cfg.enableWorkDivarDeepseek ".config/work-divar-deepseek-claude"
              ++ lib.optional cfg.enablePersonalDeepseek ".config/personal-deepseek-claude"
              ++ lib.optional cfg.enableWork ".config/work-claude"
              ++ lib.optional cfg.enableLocal ".config/local-claude"
              ++ lib.optional cfg.enablePersonal ".config/personal-claude"
            )
        );
      }
    )
  ];
}
