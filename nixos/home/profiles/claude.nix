{
  imports = [
    ../modules/personal.nix
    ../modules/work.nix
    ../modules/power-profile.nix
    ../modules/programs/development/claude-code.nix
    ../modules/programs/development/ntfy.nix
  ];

  home = {
    stateVersion = "24.11";
    sessionVariables.EDITOR = "vim";
  };

  xdg.enable = true;

  custom.claudeCode = {
    enable = true;
    enablePersonalDeepseek = true;
    enableCaveman = true;
  };
}
