{ config, dotfilesRoot, inputs, ... }:
{
  imports = [
    ../modules/shell
    ../modules/neovim.nix
    ../modules/dev-environment.nix
    ../modules/packages/dev-core.nix
    ../modules/programs/development/core.nix
    ../modules/programs/development/claude-code.nix
    ../modules/programs/development/agent-skills.nix
  ];

  custom = {
    neovim.enable = true;
    neovim.source = "${dotfilesRoot}/nvim";
    claudeCode.enable = true;

    agentSkills = {
      enable = true;
      localPath = inputs.self + "/skills";
      sources = {
        samber-go = {
          input = "samber-go-skills";
          subdir = "skills";
          idPrefix = "samber-go";
        };
      };
      targets = {
        agents.enable = true;
        gap-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/gap-claude/skills";
          structure = "symlink-tree";
        };
        claude-work = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/claude-work/skills";
          structure = "symlink-tree";
        };
      };
      skills = [
        "samber-go/golang-code-style"
        "samber-go/golang-design-patterns"
      ];
    };
  };
}
