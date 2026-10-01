{ pkgs, ... }:
{
  home.packages = [
    pkgs.grim
    pkgs.slurp
    pkgs.hyprpicker

    pkgs.wl-clipboard
    pkgs.wl-clip-persist
    pkgs.wtype
    pkgs.libnotify
    pkgs.pavucontrol
    pkgs.xwininfo
    pkgs.brightnessctl
  ];
}
