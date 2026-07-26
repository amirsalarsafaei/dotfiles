{ config
, lib
, pkgs
, secrets
, ...
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
  workMcpServers = {
    mcpServers = {
      "agentic-development-mcps" = {
        type = "http";
        url = "https://agentic-development-mcps.divar.dev/mcp";
      };
    };
  };

  localMcpConfigRel = ".config/local-claude/mcp-servers.json";
  localMcpConfigPath = "${config.home.homeDirectory}/${localMcpConfigRel}";
  localMcpServers = {
    mcpServers = {
      godot = {
        command = "npx";
        args = [ "@coding-solo/godot-mcp" ];
      };
    };
  };

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

      ${healClaudeState}/bin/heal-claude-json || true
      exec ${pkgs.claude-code}/bin/claude "$@"
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
      ${healClaudeState}/bin/heal-claude-json || true
      exec ${pkgs.claude-code}/bin/claude --mcp-config ${workMcpConfigPath} "$@"
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
    base
    // lib.optionalAttrs (plugins != { } || base ? enabledPlugins) {
      # Merge, don't clobber: `base` may carry variant-specific entries (e.g.
      # workSettings' conditional "devar@divar"); cfg.plugins toggles win.
      enabledPlugins = (base.enabledPlugins or { }) // plugins;
    };

  localSettings = {
    env = {
      CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "80";
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "131072";
    };
    permissions = {
      allow = [
        "Bash(*)"
      ];
      defaultMode = "auto";
    };
    theme = "dark";
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
        # devar plugin CLI (flags cookie editor + offline divarrpc lookup:
        # widget/struct/list/enum/support/services/godoc/grep/usages/repos).
        # The skills invoke these directly; one entry covers every subcommand.
        "Bash(devar:*)"
        # The bundled `devar` MCP server (same lookups exposed as tools). Server
        # id is plugin_<plugin>_<server> = plugin_devar_devar; trust the whole
        # server so its read-only lookup tools don't prompt.
        "mcp__plugin_devar_devar"
      ];
      deny = [
        "Bash(kubectl:*)"
        "Bash(k *)"
      ];
      defaultMode = "auto";
    };
    # Register the local devar plugin checkout as the "divar" marketplace so the
    # plugin below is enabled non-interactively instead of via `/plugin
    # marketplace add`. Gated on enableDevar (set by modules/work.nix → isWork)
    # so it lands only on the work laptop, the host that has the ~/divar/devar
    # checkout (the inputs.devar flake-input path). A directory source needs no
    # clone and no git.divar.cloud SSH key, and a directory path (unlike an
    # SCP-style git URL) is a valid source that /doctor accepts. The nested
    # `source` shape mirrors what Claude Code writes to known_marketplaces.json.
    extraKnownMarketplaces = lib.optionalAttrs cfg.enableDevar {
      divar = {
        source = {
          source = "directory";
          path = "${config.home.homeDirectory}/divar/devar";
        };
      };
    };
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
    // lib.optionalAttrs cfg.enableDevar {
      # Divar SDUI helper: `devar flags` cookie editor + offline divarrpc
      # widget/payload/enum lookup (CLI + the `devar` MCP server) + the Divar
      # skill set. plugin "devar" @ marketplace "divar" (directory source above).
      "devar@divar" = true;
    };
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
  pickerEntry = tag: name: desc: bin: { inherit tag name desc bin; };
  pickerVariants =
    lib.optional cfg.enable (pickerEntry "gap" "gap-claude" "gapgpt cloud" gapClaude)
    ++ lib.optional cfg.enableGlm (pickerEntry "glm" "glm-claude" "GLM via raytone" glmClaude)
    ++ lib.optional cfg.enableWork (pickerEntry "work" "claude-work" "Divar work, xhigh" claudeWork);

  pickerTags = map (v: v.tag) pickerVariants;
  pickerCases = lib.concatStringsSep "\n" (map
    (
      v: "          ${v.tag}) printf 'launching %s (%s)\\n' \"${v.name}\" \"${v.desc}\"; exec ${v.bin}/bin/${v.name} \"$@\" ;;"
    )
    pickerVariants);

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
      home.file.${workMcpConfigRel}.text = builtins.toJSON workMcpServers;
    })
    (lib.mkIf cfg.enableLocal {
      home.packages = [ localClaude ];
      home.file.".config/local-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "local" localSettings)
      );
      home.file.".config/local-claude/CLAUDE.md".text = nixManagedNote;
      home.file.${localMcpConfigRel}.text = builtins.toJSON localMcpServers;
    })
    (lib.mkIf (cfg.enable || cfg.enableWork || cfg.enableLocal) {
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
          )
      );
    })
  ];
}
