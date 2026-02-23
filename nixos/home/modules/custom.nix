{
  lib,
  inputs,
  pkgs,
  ...
}:
{
  options.custom.hyprland.package = lib.mkOption {
    type = lib.types.package;
    default = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    description = "Hyprland package to use";
  };
}
