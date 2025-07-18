{ inputs
, pkgs
, ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    extraConfig = builtins.readFile ./hyprland.conf;
  };
}
