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
    claudeCode.plugins.personal."clangd-lsp@claude-plugins-official" = true;

    agentSkills = {
      enable = true;
      localPath = inputs.self + "/skills";
      sources = {
        samber-go = {
          input = "samber-go-skills";
          subdir = "skills";
        };
      };
      targets = {
        agents.enable = true;
        gap-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/gap-claude/skills";
          structure = "symlink-tree";
        };
        work-claude = {
          enable = true;
          dest = "${config.home.homeDirectory}/.config/work-claude/skills";
          structure = "symlink-tree";
        };
      };
      skills = [
        "golang-grpc"
        "golang-how-to"
        "golang-naming"
        "golang-stretchr-testify"
        "golang-testing"
      ];
    };
  };
}
