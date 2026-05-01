{
  pkgs,
  config,
  themeLib,
  ...
}:
let
  theme = config.custom.theme.resolved;
  styleConfig = import ./hyprlock/styles/default.nix {
    inherit pkgs theme themeLib;
  };
in
{
  programs.hyprlock = {
    enable = true;
    package = pkgs.hyprlock;

    settings = styleConfig.settings;
    extraConfig = styleConfig.extraConfig;
  };
}
