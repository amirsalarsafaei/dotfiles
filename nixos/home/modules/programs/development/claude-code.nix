{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.custom.claudeCode;

  mkVariant =
    {
      name,
      configDir,
      extraWrapperArgs ? [ ],
    }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
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
      ];
      deny = [
        "Bash(kubectl:*)"
        "Bash(k *)"
      ];
      defaultMode = "auto";
    };
    enabledPlugins = {
      "gopls-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
    };
    effortLevel = "high";
    theme = "dark";
    skipAutoPermissionPrompt = true;
  };

  gapSettings = {
    theme = "dark";
  };

  withOverrides = base:
    base // lib.optionalAttrs (cfg.skillOverrides != { }) {
      skillOverrides = cfg.skillOverrides;
    };

  nixManagedNote = "settings.json is Nix-managed (home/modules/programs/development/claude-code.nix in your dotfiles flake) — edits won't persist; change Nix and rebuild.\n";
in
{
  options.custom.claudeCode = {
    enable = lib.mkEnableOption "Install claude-code and the gap-claude wrapper";
    enableWork = lib.mkEnableOption "Install the claude-work variant (work-host only)";

    skillOverrides = lib.mkOption {
      type = with lib.types; attrsOf (enum [ "on" "user-invocable-only" "name-only" "off" ]);
      default = { };
      example = lib.literalExpression ''
        {
          golang-design-patterns = "user-invocable-only";
        }
      '';
      description = ''
        Per-skill visibility overrides written to settings.json under
        `skillOverrides`. Applies to all enabled Claude Code variants.

        Values:
          - "on"                  : default; auto-listed to the model
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
      home.file.".config/gap-claude/settings.json".text =
        builtins.toJSON (withOverrides gapSettings);
      home.file.".config/gap-claude/CLAUDE.md".text = nixManagedNote;
    })
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
      home.file.".config/claude-work/settings.json".text =
        builtins.toJSON (withOverrides workSettings);
      home.file.".config/claude-work/CLAUDE.md".text = nixManagedNote;
    })
  ];
}
