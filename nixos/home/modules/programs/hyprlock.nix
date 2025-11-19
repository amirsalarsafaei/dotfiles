{pkgs, ...}:
let
  # Import the default hyprlock style
  styleConfig = import ./hyprlock/styles/default.nix { inherit pkgs; };
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
