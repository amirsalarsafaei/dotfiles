{ pkgs, config, ... }:
let
  t = config.theme;
  styleConfig = import ./hyprlock/styles/default.nix { inherit pkgs t; };
in
{
  programs.hyprlock = {
    enable = true;
    package = pkgs.hyprlock;

    # Apply the style configuration
    settings = styleConfig.settings;
    extraConfig = styleConfig.extraConfig;
  };
}
