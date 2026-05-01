{ pkgs, currentSystem, ... }:
pkgs.lib.optionals (currentSystem == "x86_64-linux") [
  pkgs.zoom-us
  pkgs.android-studio
  pkgs.discord
  pkgs.insomnia
  pkgs.blender
]
