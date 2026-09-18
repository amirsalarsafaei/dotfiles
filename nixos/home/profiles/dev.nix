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
    ../modules/scripts/user.nix # file-based user scripts (custom.userScripts)
    ../modules/packages/dev-core.nix
    ../modules/programs/development/core.nix
    ../modules/programs/development/claude-code.nix
    ../modules/programs/development/opencode.nix
    ../modules/programs/development/agent-skills.nix
    ../modules/programs/development/ntfy.nix
  ];

  custom = {
    neovim.enable = true;
    claudeCode.enable = true;
    claudeCode.enablePersonal = true;
    claudeCode.enablePersonalDeepseek = true;
    claudeCode.enableCaveman = true;
    claudeCode.enableObsidian = true;
    claudeCode.plugins.personal."clangd-lsp@claude-plugins-official" = true;
    claudeCode.skillOverrides.nix-environment = "on";

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
          enable = true;
          dest = "${config.home.homeDirectory}/.config/local-claude/skills";
          structure = "symlink-tree";
        };
        personal-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/personal-claude/skills";
          structure = "symlink-tree";
        };
        personal-deepseek-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/personal-deepseek-claude/skills";
          structure = "symlink-tree";
        };
        work-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/work-claude/skills";
          structure = "symlink-tree";
        };
      };
      # All 46 golang-* skills from samber/cc-skills-golang. defaultSkillMode
      # ("user-invocable-only") keeps every one hidden from the model — invokable
      # via /golang-* only — so enabling the whole pack doesn't flood context.
      enableAll = [ "samber-go" ];
    };
  };
}
