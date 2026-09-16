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

  # The zellij status-bar plugin and its Claude Code hook bridge are one
  # package; the plugin half is used by home/modules/programs/terminal/zelij.nix.
  zellaude = pkgs.callPackage ../../../../pkgs/zellaude.nix { };

  devar = pkgs.callPackage ../../../../pkgs/devar.nix { devarSrc = inputs.devar; };

  workEffortLevel = "xhigh";

  # Paths the bwrap sandbox must never let a Bash-tool subprocess read or
  # write, regardless of variant: SSH/GPG keyrings and every provider API key
  # file on disk. Nix derivations never get ambient access to secrets either
  # (git-crypt'd secrets.json, no impure env) — this is the same discipline
  # applied to the sandboxed Bash tool.
  sandboxSecretDenyPaths = [
    "${config.home.homeDirectory}/.ssh"
    "${config.home.homeDirectory}/.gnupg"
    "${config.home.homeDirectory}/.aws"
    "${config.home.homeDirectory}/.config/gh"
    "${config.home.homeDirectory}/glm-key"
    "${config.home.homeDirectory}/deepseek-key"
    "${config.home.homeDirectory}/personal-deepseek"
  ];

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

  # Conversation sharing across sibling variants: each work variant (work /
  # glm / deepseek) and each personal variant (personal / personal-deepseek)
  # owns its CLAUDE_CONFIG_DIR outright — own .claude.json, plugins, cache,
  # daemon, live-session state — so siblings never fight over shared state.
  # Only the conversation stores are shared: `projects/` (the --resume
  # transcripts) and `history.jsonl` (prompt history) live once in a
  # <group>-shared dir and each sibling symlinks them in (home.file entries
  # built by mkConversationShareFiles below). Session discovery reads the
  # .jsonl files off disk, so a symlinked projects/ is enough for `--resume`
  # in any sibling to list and continue sessions started under another.
  workClaudeConfigDir = "${config.home.homeDirectory}/.config/work-claude";
  glmClaudeConfigDir = "${config.home.homeDirectory}/.config/glm-claude";
  deepseekClaudeConfigDir = "${config.home.homeDirectory}/.config/deepseek-claude";
  personalClaudeConfigDir = "${config.home.homeDirectory}/.config/personal-claude";
  personalDeepseekClaudeConfigDir = "${config.home.homeDirectory}/.config/personal-deepseek-claude";

  workClaudeSharedDir = "${config.home.homeDirectory}/.config/work-claude-shared";
  personalClaudeSharedDir = "${config.home.homeDirectory}/.config/personal-claude-shared";

  conversationShareNames = [
    "projects"
    "history.jsonl"
  ];

  # home.file entries symlinking a variant dir's conversation stores at the
  # group's shared dir. mkOutOfStoreSymlink keeps these plain absolute
  # symlinks, so Claude Code writes land in the shared dir directly.
  mkConversationShareFiles =
    sharedDir: variantDir:
    lib.listToAttrs (
      map
        (name: {
          name = "${variantDir}/${name}";
          value.source = config.lib.file.mkOutOfStoreSymlink "${sharedDir}/${name}";
        })
        conversationShareNames
    );

  # One-time migration, run before checkLinkTargets so the symlinks above can
  # replace what a variant still owns as real files/dirs: pre-sharing layouts
  # (each variant with its own projects/) and dirs stranded by wrappers from
  # before this grouping. Merges each variant's real conversation stores into
  # the shared dir (transcript files are UUID-named, so cp --no-clobber
  # collisions are impossible), then removes the originals. Idempotent: a
  # symlinked or absent store is left alone.
  mkConversationShareMigration =
    sharedDir: variantDirs:
    ''
      _cc_shared="${sharedDir}"
      mkdir -p "$_cc_shared/projects"
      [ -f "$_cc_shared/history.jsonl" ] || : > "$_cc_shared/history.jsonl"
      for _cc_v in ${lib.concatStringsSep " " variantDirs}; do
        [ -d "$_cc_v" ] || continue
        if [ -d "$_cc_v/projects" ] && [ ! -L "$_cc_v/projects" ]; then
          if [ -z "$(ls -A "$_cc_shared/projects" 2>/dev/null)" ]; then
            # shared store still empty: -T renames onto the (empty) target —
            # atomic and lossless, no copy of hundreds of MB
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

  agenticMcpParserText = mkBoolFlagParser {
    flag = "--agentic-mcps";
    resultVar = "_claude_agentic_mcps";
  };

  gitlabMcpParserText = mkBoolFlagParser {
    flag = "--gitlab-mcp";
    resultVar = "_claude_gitlab_mcp";
  };

  # Single source of truth for CLI flags that flip a plugin on or off for one
  # launch, via a `--settings` JSON overlay merged over the variant's
  # settings.json (the same trick --no-devar always used). Add an entry here
  # to get: the CLI flag on every variant (pluginFlagsParserText below), the
  # marketplace injected into that same overlay when — and only when — the flag
  # is passed (so an unflagged launch never sees it in /plugin, yet the plugin
  # stays resolvable once enabled), and zsh completion for the flag
  # (flagPluginsZshArgs, consumed by home/modules/shell/zsh/functions.nix) —
  # nothing else to touch.
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
  # `env` is exported via the overlay whenever the flag is passed; `levelEnv`
  # adds a `<flag>=<level>` form that also sets that variable to the level.
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
  };

  flagPluginsZshArgs = lib.concatMapStringsSep " " (
    p: "'${p.flag}[${p.desc}]'"
  ) flagPlugins;

  pluginFlagsParserText =
    let
      armBody = p: ''
        _claude_plugin_flags+=("${p.plugin}=${if p.enable then "true" else "false"}")
        ${lib.optionalString (p ? marketplace)
          ''_claude_plugin_marketplaces+=('${builtins.toJSON p.marketplace}')''
        }
        ${lib.concatMapStringsSep "\n" (
          k: "_claude_plugin_env+=(${lib.escapeShellArg "${k}=${p.env.${k}}"})"
        ) (lib.attrNames (p.env or { }))}
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
        # Seed the overlay with the marketplaces the variant's own settings.json
        # already registers, then add the flag's own — a --settings overlay
        # replaces this key wholesale, so re-stating them keeps devar/caveman/
        # ast-grep resolvable on a flagged launch.
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
        # Same wholesale-replace caveat as above: carry the variant's own env
        # (CLAUDE_OBSIDIAN_VAULT, a Nix-set CAVEMAN_DEFAULT_MODE) into the overlay
        # so the flag's values override it instead of wiping it.
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
    unset _claude_plugin_flags _claude_plugin_marketplaces _claude_plugin_env
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

  # Plugin registries store absolute paths, so a renamed CLAUDE_CONFIG_DIR
  # (normal-claude -> personal-claude) left every older marketplace pointing
  # at a dead dir and failing as "cache-miss". Paths are re-rooted onto the
  # current dir only when the data is already there; nothing is dropped.
  healClaudeState = pkgs.writeShellApplication {
    name = "heal-claude-json";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      dir="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      plugins="$dir/plugins"

      # $tmp holds the jq rewrite of $file; swap it in only if jq produced output.
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

  # Common tail of the work-group wrappers (work/glm/deepseek). Each variant
  # owns its CLAUDE_CONFIG_DIR, so its settings.json is read natively and the
  # --settings overlay is only needed for plugin-toggle flags.
  # agentic-development-mcps is not attached here at all: devar's MCP server
  # embeds it unconditionally (the upstream list is code in devar, its OAuth
  # devar's own — `devar mcp login platform` once). Personal-claude keeps the
  # direct attachment as an opt-in flag (personal runs no devar).
  workWrapperTail = ''
    ${effortParserText}
    ${pluginFlagsParserText}

    ${healClaudeState}/bin/heal-claude-json || true
    ${pluginSettingsArgText}
    exec ${pkgs.claude-code}/bin/claude "''${_claude_extra_args[@]}" "$@"
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
      export CLAUDE_VARIANT_NAME="glm-claude"
      export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
      export ANTHROPIC_MODEL="glm-5.3[1m]"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.3[1m]"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.3[1m]"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-5.3-flash[1m]"
      export CLAUDE_CODE_SUBAGENT_MODEL="glm-5.3[1m]"
      export CLAUDE_CONFIG_DIR="${glmClaudeConfigDir}"
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

  # Same DeepSeek native-Anthropic endpoint as deepseek-claude above, but for
  # personal (non-work) use: its own key file, no work MCP config / devar
  # plugin. Own CLAUDE_CONFIG_DIR, with only the conversation stores shared
  # with personal-claude (see personalClaudeSharedDir) so `--resume` sees
  # sessions from either.
  personalDeepseekClaude = pkgs.writeShellApplication {
    name = "personal-deepseek-claude";
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
      ${effortParserText}
      ${pluginFlagsParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      exec ${pkgs.claude-code}/bin/claude "''${_claude_extra_args[@]}" "$@"
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

      # Abbreviate every path segment but the leading ~ (if any) and the
      # final one down to its first character, e.g.
      # ~/personal/dotfiles/nixos -> ~/p/d/nixos
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

      # Render a used-percentage as a compact 5-block gauge, e.g. "███░░42%"
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
      # The flag files outlive a --caveman launch, so trust them only when this
      # session actually loaded the plugin (mkSettings / the flag set the marker).
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
      export TZ="Europe/Berlin"
      export TZDIR="${pkgs.tzdata}/share/zoneinfo"
      ${effortParserText}
      ${agenticMcpParserText}
      ${gitlabMcpParserText}
      ${pluginFlagsParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
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
      export CLAUDE_VARIANT_NAME="gap-claude"
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/gap-claude"
      export ANTHROPIC_API_KEY="${secrets.gapgpt.apiKey or ""}"
      export ANTHROPIC_BASE_URL="https://api.gapgpt.app/"
      ${effortParserText}
      ${pluginFlagsParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      exec ${pkgs.claude-code}/bin/claude "''${_claude_extra_args[@]}" "$@"
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
      export CLAUDE_VARIANT_NAME="work-claude"
      export CLAUDE_CONFIG_DIR="${workClaudeConfigDir}"
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
      ${effortParserText}
      ${pluginFlagsParserText}
      ${healClaudeState}/bin/heal-claude-json || true
      ${pluginSettingsArgText}
      exec claude --mcp-config "${localMcpConfigPath}" "''${_claude_extra_args[@]}" "$@"
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

  # Best-effort ntfy ping on the "claude" topic (home/modules/programs/
  # development/ntfy.nix) when any variant's session ends. The hook script
  # itself swallows failures, so a missing token or dead network never blocks
  # Claude from finishing.
  ntfyStopHooks = lib.optionalAttrs config.custom.ntfy.enableClaudeHook {
    Stop = [
      {
        hooks = [
          {
            type = "command";
            command = "${config.custom.ntfy.claudeHookPackage}/bin/ntfy-claude-hook";
            timeout = 10;
          }
        ];
      }
    ];
  };

  # `variant` keys cfg.plugins, where work/glm/deepseek share "work"; `name` is
  # the variant's own identity, for settings that must not be shared.
  mkSettings =
    variant: name: base:
    let
      plugins = cfg.plugins.default // cfg.plugins.${variant};
      # claude-obsidian goes on every variant except local-claude, which the
      # user keeps deliberately minimal (fewer plugins = less model context).
      obsidian = cfg.enableObsidian && variant != "local";
      cavemanMode = cfg.cavemanMode.${name};
      caveman = cfg.enableCaveman && cavemanMode != null;
      marketplaces =
        lib.optionalAttrs obsidian obsidianMarketplace // lib.optionalAttrs caveman cavemanMarketplace;
      env =
        # Keeps Claude's renderer in the terminal's normal scrollback instead
        # of the alternate screen. Inside zellij (mouse_mode = true, see
        # zelij.nix), an alt-screen pane has no native scrollback, so mouse
        # wheel scroll gets translated into rapid Up/Down keypresses forwarded
        # to the app — Claude's input layer reads that burst as a paste. This
        # keeps zellij's own pane scrollback in play for the wheel instead, so
        # click-drag select-to-copy (also mouse_mode) is unaffected.
        {
          CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
        }
        // lib.optionalAttrs obsidian { CLAUDE_OBSIDIAN_VAULT = obsidianVaultPath; }
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
    // lib.optionalAttrs (plugins != { } || base ? enabledPlugins || obsidian || caveman) {
      # cfg.plugins last, so a per-variant `false` can still switch these off.
      enabledPlugins =
        (base.enabledPlugins or { })
        // lib.optionalAttrs obsidian obsidianPlugin
        // lib.optionalAttrs caveman cavemanPlugin
        // plugins;
    }
    // lib.optionalAttrs (marketplaces != { }) {
      extraKnownMarketplaces = (base.extraKnownMarketplaces or { }) // marketplaces;
    }
    // lib.optionalAttrs (env != { }) {
      env = (base.env or { }) // env;
    }
    // {
      hooks = lib.zipAttrsWith (_: lib.concatLists) [
        zellaudeHooks
        ntfyStopHooks
        (base.hooks or { })
      ];
      # denyRead/denyWrite here are bwrap sandbox paths (OS-level, for the
      # Bash tool), unrelated to the Read/Edit tool permission deny rules
      # above — keeping every variant's Bash tool blind to key material even
      # if a permission rule is misconfigured.
      sandbox = {
        denyRead = sandboxSecretDenyPaths;
        denyWrite = sandboxSecretDenyPaths;
      } // (base.sandbox or { });
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

  # github-sourced marketplace registration, same shape devarMarketplace above
  # uses for its directory source: non-interactive `extraKnownMarketplaces`
  # entry + a matching `enabledPlugins` toggle.
  mkGithubMarketplace = repo: {
    source = {
      source = "github";
      inherit repo;
    };
  };

  # Gated on enableCaveman + cavemanMode.<variant> in mkSettings, and on the
  # --caveman flag (flagPlugins) for variants that leave it unloaded.
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

  # ast-grep's official Claude Code skill (github.com/ast-grep/agent-skill):
  # teaches structural/AST-based code search with the `ast-grep` CLI (see
  # home/modules/packages/dev.nix for the package). Always on, every variant —
  # unlike devar/caveman there is no host- or preference-gate for it.
  astGrepMarketplace = {
    "ast-grep-marketplace" = mkGithubMarketplace "ast-grep/agent-skill";
  };

  astGrepPlugin = {
    "ast-grep@ast-grep-marketplace" = true;
  };

  # claude-obsidian: github-sourced marketplace + plugin, same shape caveman/
  # ast-grep use. The plugin's own hooks and skills shell out to `python3
  # <plugin-root>/scripts/claude-obsidian.py`, which is stdlib-only (Python
  # 3.11+, already on PATH via the dev profile), so no compiled binary or flake
  # input is needed — Claude Code clones the repo at first launch.
  #
  # Not gated with lib.optionalAttrs here; the enableObsidian/`variant != "local"`
  # decision lives in mkSettings so it lands on every variant but local-claude.
  obsidianMarketplace = {
    "agricidaniel-claude-obsidian" = mkGithubMarketplace "AgriciDaniel/claude-obsidian";
  };

  obsidianPlugin = {
    "claude-obsidian@agricidaniel-claude-obsidian" = true;
  };

  # Must stay in sync with `vaultRel` in home/modules/programs/desktop/obsidian.nix.
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
    enabledPlugins = {
      "figma@claude-plugins-official" = true;
    }
    // devarPlugin
    // astGrepPlugin;
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
  };

  personalDeepseekSettings = {
    theme = "dark";
    env = {
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    };
    extraKnownMarketplaces = astGrepMarketplace;
    enabledPlugins = astGrepPlugin;
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
    ++ lib.optional cfg.enableGlm (pickerEntry "glm" "glm-claude" "GLM via z.ai" glmClaude)
    ++ lib.optional cfg.enableDeepseek (
      pickerEntry "deepseek" "deepseek-claude" "DeepSeek, native Anthropic API" deepseekClaude
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
        personalDeepseek = mkMode "personal-deepseek-claude" null;
        gap = mkMode "gap-claude" null;
        local = mkMode "local-claude" null;
      };
    enableObsidian = lib.mkEnableOption ''
      the claude-obsidian plugin (github.com/AgriciDaniel/claude-obsidian): a
      local-first "second brain" for an Obsidian vault — source-cited wiki
      pages, research/retrieval/lint skills, and recoverable transactions.
      Registered as a github plugin marketplace, same mechanism as enableCaveman,
      and enabled on every variant except local-claude (kept minimal on purpose).
      Points CLAUDE_OBSIDIAN_VAULT at ~/Documents/amirsalar-vault; adopt that
      vault once with /claude-obsidian:wiki after the first launch
    '';

    glmPrices = lib.mkOption {
      type = lib.types.submodule {
        options = {
          input = lib.mkOption {
            type = lib.types.float;
            default = 1.40;
            description = "USD per 1M non-cache input tokens for the glm-5.3 endpoint.";
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
        Per-1M-token USD prices for the glm-5.3 (z.ai) endpoint, consumed by
        the `glm-usage` tracker and its statusline week/month cost. Override
        per-host if your plan's rates differ.
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
      # The crit@crit plugin's hooks shell out to a bare `crit` on PATH (its
      # own binary, built from the crit flake input via the overlay in
      # flake.nix). The plugin marketplace registration only ships the
      # skill/slash-command; without this the `--crit` flag enables a plugin
      # whose commands fail with "crit: command not found".
      home.packages = [ pkgs.crit ];
    }
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
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
      home.file.".config/work-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" "work" workSettings)
      );
      home.file.".config/work-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf (cfg.enableWork || cfg.enableGlm || cfg.enablePersonal || cfg.enableDeepseek) {
      home.file.${workMcpConfigRel}.text = builtins.toJSON workMcpServers;
    })
    (lib.mkIf (cfg.enableWork || cfg.enableGlm || cfg.enableDeepseek) {
      # Conversation sharing across the work group — see mkConversationShareFiles.
      home.file =
        (lib.optionalAttrs cfg.enableWork (
          mkConversationShareFiles workClaudeSharedDir ".config/work-claude"
        ))
        // (lib.optionalAttrs cfg.enableGlm (
          mkConversationShareFiles workClaudeSharedDir ".config/glm-claude"
        ))
        // (lib.optionalAttrs cfg.enableDeepseek (
          mkConversationShareFiles workClaudeSharedDir ".config/deepseek-claude"
        ));
      home.activation.claudeWorkConversationMigration = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
        mkConversationShareMigration workClaudeSharedDir (
          lib.optional cfg.enableWork workClaudeConfigDir
          ++ lib.optional cfg.enableGlm glmClaudeConfigDir
          ++ lib.optional cfg.enableDeepseek deepseekClaudeConfigDir
        )
      );
    })
    (lib.mkIf (cfg.enablePersonal || cfg.enablePersonalDeepseek) {
      # Same conversation sharing for the personal pair.
      home.file =
        (lib.optionalAttrs cfg.enablePersonal (
          mkConversationShareFiles personalClaudeSharedDir ".config/personal-claude"
        ))
        // (lib.optionalAttrs cfg.enablePersonalDeepseek (
          mkConversationShareFiles personalClaudeSharedDir ".config/personal-deepseek-claude"
        ));
      home.activation.claudePersonalConversationMigration = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
        mkConversationShareMigration personalClaudeSharedDir (
          lib.optional cfg.enablePersonal personalClaudeConfigDir
          ++ lib.optional cfg.enablePersonalDeepseek personalDeepseekClaudeConfigDir
        )
      );
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
