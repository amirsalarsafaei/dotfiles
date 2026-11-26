{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals config.custom.personal.enable [
    pkgs.hmcl
    pkgs.heroic
    (pkgs.bottles.override { removeWarningPopup = true; })
  ];
}
