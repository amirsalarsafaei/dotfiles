{
  config,
  inputs,
  ...
}:
{
  imports = [
    ../modules/shell
    ../modules/neovim
    ../modules/dev-environment.nix
    ../modules/scripts/user.nix
    ../modules/packages/dev-core.nix
    ../modules/programs/development/core.nix
    ../modules/programs/development/claude-code.nix
    ../modules/programs/development/opencode.nix
    ../modules/programs/development/agent-skills.nix
    ../modules/programs/development/ntfy.nix
  ];

  custom = {
    neovim.enable = true;
    claudeCode = {
      enable = true;
      enablePersonal = config.custom.personal.enable;
      enablePersonalDeepseek = config.custom.personal.enable;
      enableCaveman = true;
      planner.enable = true;
      plugins.personal."clangd-lsp@claude-plugins-official" = true;
      skillOverrides.nix-environment = "on";
    };
    ntfy.enable = config.custom.personal.enable;

    agentSkills = {
      enable = true;
      localPath = inputs.self + "/skills";
      sources = {
        samber-go = {
          input = "samber-go-skills";
          subdir = "skills";
        };
      };
      skills = [ "nix-environment" ];
      targets = {
        agents.enable = true;
        gap-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/gap-claude/skills";
          structure = "symlink-tree";
        };
        local-claude = {
          enable = config.custom.claudeCode.enableLocal;
          dest = "${config.home.homeDirectory}/.config/local-claude/skills";
          structure = "symlink-tree";
        };
        personal-claude = {
          enable = config.custom.claudeCode.enablePersonal;
          dest = "${config.home.homeDirectory}/.config/personal-claude/skills";
          structure = "symlink-tree";
        };
        personal-deepseek-claude = {
          enable = config.custom.claudeCode.enablePersonalDeepseek;
          dest = "${config.home.homeDirectory}/.config/personal-deepseek-claude/skills";
          structure = "symlink-tree";
        };
        work-claude = {
          enable = config.custom.claudeCode.enableWork;
          dest = "${config.home.homeDirectory}/.config/work-claude/skills";
          structure = "symlink-tree";
        };
      };
      sourceTargets.samber-go = [ "agents" ];
    };
  };
}
