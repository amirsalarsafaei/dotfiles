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

  mkVariant =
    {
      name,
      configDir,
      extraWrapperArgs ? [ ],
      extraBuildInputs ? [ ],
    }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.makeWrapper ] ++ extraBuildInputs; } ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.claude-code}/bin/claude $out/bin/${name} \
        --set CLAUDE_CONFIG_DIR "${configDir}" \
        ${lib.concatStringsSep " " extraWrapperArgs}

    '';

  gapClaude = mkVariant {
    name = "gap-claude";
    configDir = "${config.home.homeDirectory}/.config/gap-claude";
    extraWrapperArgs = [
      ''--set ANTHROPIC_API_KEY "${secrets.gapgpt.apiKey or ""}"''
      ''--set ANTHROPIC_BASE_URL "https://api.gapgpt.app/"''
    ];
  };

  claudeWork = mkVariant {
    name = "claude-work";
    configDir = "${config.home.homeDirectory}/.config/claude-work";
    extraBuildInputs = [ pkgs.tzdata ];
    extraWrapperArgs = [
      ''--set TZ "Asia/Singapore"''
      ''--set TZDIR "${pkgs.tzdata}/share/zoneinfo"''
      # Env var, not just settings.json effortLevel: the latter loses to the
      # model default on first run, and /effort can't override it because it
      # persists by writing the read-only Nix settings.json symlink.
      ''--set CLAUDE_CODE_EFFORT_LEVEL "${workEffortLevel}"''
    ];
  };

  # Local-model variant: a thin wrapper that points Claude Code at a local
  # GGUF served by llama-swap (see hosts/g14/local-llm.nix). claude-code-router
  # ("ccr") translates Anthropic Messages <-> OpenAI chat-completions and
  # injects ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN before spawning `claude`,
  # so all we do is set our own config dir and hand off to `ccr code`.
  localClaude = pkgs.writeShellApplication {
    name = "local-claude";
    runtimeInputs = [
      pkgs.claude-code-router
      pkgs.claude-code
    ];
    text = ''
      export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.config/local-claude"
      # ccr injects ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN and silently routes
      # every request to the local model, but it does NOT change the model name
      # Claude Code shows — so without this the statusline reads "opus" (the
      # cloud default) even though nothing hits the cloud. Pin the model names so
      # the UI reflects reality and nothing can fall through to Anthropic.
      #   - main model      -> qwen3.6-apex          (thinking ON, server default)
      #   - small/fast model-> local,<nothink alias> (direct-routed so ccr applies
      #     the `reasoning` transformer, which sets enable_thinking=false on the
      #     thinking-less background chores: titles, topic checks, summaries).
      # Both names resolve to the SAME loaded llama-swap process (alias), so there
      # is no second model in VRAM and no swapping.
      export ANTHROPIC_MODEL="${localModel}"
      export ANTHROPIC_SMALL_FAST_MODEL="local,${localModelFast}"
      exec ccr code "$@"
    '';
  };

  # ccr routing config. Every route points at the single local model; the
  # name after the comma is the model id forwarded to llama-swap (which keys
  # its model entry on "qwen3.6-apex"). Timeouts are generous since local
  # generation is far slower than the cloud.
  localModel = "qwen3.6-apex";
  # Same underlying llama-swap model (registered as an alias there), but a
  # distinct ccr model name so we can hang the `reasoning` transformer on it.
  # That transformer sets enable_thinking=false whenever a request carries no
  # reasoning directive — i.e. exactly the background chores — so the fast
  # model skips thinking while the main model keeps it. No extra VRAM.
  localModelFast = "qwen3.6-apex-nothink";
  # Custom ccr transformer: llama.cpp only honors chat_template_kwargs for the
  # Qwen3 thinking toggle (verified: the built-in `reasoning` transformer sets
  # top-level enable_thinking/thinking, which llama.cpp ignores). This injects
  # the field that actually works, and we attach it to the fast/background
  # model only.
  ccrPluginPath = "${config.home.homeDirectory}/.claude-code-router/plugins/nothink.js";
  ccrNoThinkPlugin = ''
    // Force Qwen3 to skip <think> by injecting the only field llama.cpp honors.
    class NoThink {
      constructor(options) { this.options = options || {}; this.name = "nothink"; }
      async transformRequestIn(request) {
        request.chat_template_kwargs = Object.assign(
          {}, request.chat_template_kwargs, { enable_thinking: false }
        );
        return request;
      }
    }
    module.exports = NoThink;
  '';
  ccrConfig = {
    LOG = false;
    HOST = "127.0.0.1";
    API_TIMEOUT_MS = 1800000;
    transformers = [ { path = ccrPluginPath; } ];
    Providers = [
      {
        name = "local";
        api_base_url = "http://127.0.0.1:18080/v1/chat/completions";
        api_key = "sk-local";
        models = [
          localModel
          localModelFast
        ];
        # Only the fast/background alias gets thinking stripped; the main model
        # has no transformer, so it behaves exactly as before (thinking ON).
        transformer = {
          ${localModelFast} = {
            use = [ "nothink" ];
          };
        };
      }
    ];
    Router = {
      default = "local,${localModel}";
      background = "local,${localModelFast}";
      think = "local,${localModel}";
      longContext = "local,${localModel}";
      longContextThreshold = 200000;
      webSearch = "local,${localModel}";
    };
  };

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
    // lib.optionalAttrs (plugins != { }) {
      enabledPlugins = plugins;
    };

  localSettings = {
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
    # Register the Divar `devar` plugin repo as the "divar" marketplace via its
    # git remote (self-hosted GitLab over SSH) so the plugin below is enabled
    # non-interactively instead of via `/plugin marketplace add`. Gated on
    # enableDevar (set by modules/work.nix → isWork) so it lands only on the
    # work laptop: Claude Code clones the marketplace at runtime and only that
    # host has the git.divar.cloud SSH key. The nested `source` shape mirrors
    # what Claude Code writes to plugins/known_marketplaces.json ("url" = a
    # generic git URL source, as opposed to "github"/"directory").
    extraKnownMarketplaces = lib.optionalAttrs cfg.enableDevar {
      divar = {
        source = {
          source = "url";
          url = "git@git.divar.cloud:amirsalar.safaei/devar.git";
        };
      };
    };
    enabledPlugins = {
      "gopls-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
    }
    // lib.optionalAttrs cfg.enableDevar {
      # Divar SDUI helper: `devar flags` cookie editor + offline divarrpc
      # widget/payload/enum lookup (CLI + the `devar` MCP server) + the Divar
      # skill set. plugin "devar" @ marketplace "divar" (git source above).
      "devar@divar" = true;
    };
    # effortLevel intentionally omitted: set via the CLAUDE_CODE_EFFORT_LEVEL
    # env var in claudeWork's wrapper instead (see note there). Keeping it here
    # too would be a redundant second source of truth, and the env var wins.
    theme = "dark";
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
in
{
  options.custom.claudeCode = {
    enable = lib.mkEnableOption "Install claude-code and the gap-claude wrapper";
    enableWork = lib.mkEnableOption "Install the claude-work variant (work-host only)";
    enableLocal = lib.mkEnableOption "Install the local-claude variant (claude-code-router -> local llama-swap model)";
    enableDevar = lib.mkEnableOption ''
      the Divar `devar` plugin in the work variant: the git-sourced "divar"
      marketplace and the `devar@divar` plugin entry. Set by modules/work.nix
      (isWork) so it lands only on the work laptop — the sole host with the
      git.divar.cloud SSH key Claude Code needs to clone the marketplace.
      Other claude-work hosts (e.g. g14) get the variant without devar
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
        pkgs.claude-code
        gapClaude
      ];
      home.file.".config/gap-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "gap" gapSettings)
      );
      home.file.".config/gap-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
      home.file.".config/claude-work/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "work" workSettings)
      );
      home.file.".config/claude-work/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableLocal {
      home.packages = [
        pkgs.claude-code-router
        localClaude
      ];
      home.file.".claude-code-router/config.json".text = builtins.toJSON ccrConfig;
      home.file.".claude-code-router/plugins/nothink.js".text = ccrNoThinkPlugin;
      home.file.".config/local-claude/settings.json".text = builtins.toJSON (
        withOverrides (mkSettings "local" localSettings)
      );
      home.file.".config/local-claude/CLAUDE.md".text = nixManagedNote;
    })
  ];
}
