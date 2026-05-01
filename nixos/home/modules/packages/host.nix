{ pkgs, currentHostname, ... }:
pkgs.lib.optionals (currentHostname == "g14") [
  pkgs.aseprite
  pkgs.godot
]
