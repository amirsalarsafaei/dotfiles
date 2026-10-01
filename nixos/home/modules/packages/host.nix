{
  lib,
  pkgs,
  currentHostname,
  ...
}:
{
  home.packages = lib.optionals (currentHostname == "g14") [
    pkgs.aseprite
    pkgs.godot
  ];
}
