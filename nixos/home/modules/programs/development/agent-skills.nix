{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.agentSkills;
in
{
  options.custom.agentSkills = {
    enable = lib.mkEnableOption ''
      Declarative Agent Skills via agent-skills-nix.

      Installs the selected skills under $HOME/.agents/skills so the `skill`
      tool can load them on demand. Nothing is pushed into the agent context
      automatically; only IDs listed in `custom.agentSkills.skills` (or whole
      sources via `enableAll`) are surfaced to the catalog.

      Add skill repositories as flake inputs (e.g. `samber-go-skills`,
      `anthropic-skills`, …), declare them under `custom.agentSkills.sources`,
      then opt them in via `custom.agentSkills.skills` or `enableAll`.
      Personal skills live in `home/skills/` (source name `local`).
    '';

    localPath = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = lib.literalExpression "inputs.self + \"/skills\"";
      description = ''
        Path to a directory containing personal SKILL.md directories. When
        non-null, it is registered as the `local` source with
        `idPrefix = "local"` and recursion depth 2.

        Set this from the consumer (typically `inputs.self + "/skills"`)
        so the path is anchored in the flake root rather than via brittle
        relative `../..` traversal from this module's location.
      '';
    };

    sources = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression ''
        {
          anthropic = {
            input  = "anthropic-skills";   # name in flake.nix `inputs`
            subdir = "skills";
            idPrefix = "anthropic";
          };
        }
      '';
      description = ''
        Additional skill sources merged on top of the optional `local`
        source (see `localPath`). Each source must set either `input`
        (flake input name) or `path` (Nix path). Use `idPrefix` to
        namespace IDs.
      '';
    };

    skills = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "local/my-skill"
        "samber-go/golang-stretchr-testify"
      ];
      description = ''
        Explicit allowlist of skill IDs to enable from the discovered
        catalog. Discovery is opt-in per skill unless the source is listed
        in `enableAll`.
      '';
    };

    enableAll = lib.mkOption {
      type = with lib.types; either bool (listOf str);
      default = false;
      example = [ "samber-go" ];
      description = ''
        Enable every skill from all sources (true) or from a specific list
        of source names. Useful for skill packs you want wholesale.
      '';
    };

    targets = lib.mkOption {
      type = lib.types.attrs;
      default = {
        agents = {
          enable = true;
          structure = "symlink-tree";
        };
      };
      description = ''
        Install targets. Defaults to the generic `agents` target
        ($HOME/.agents/skills) which Amp's `skill` tool reads. Override or
        extend to publish skills to specific agent layouts (claude, codex,
        opencode, …).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.agent-skills = {
      enable = true;

      sources = lib.optionalAttrs (cfg.localPath != null) {
        local = {
          path = cfg.localPath;
          subdir = ".";
          idPrefix = "local";
          filter.maxDepth = 2;
        };
      }
      // cfg.sources;

      skills = {
        enable = cfg.skills;
        enableAll = cfg.enableAll;
      };

      targets = cfg.targets;
    };
  };
}
