{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals config.custom.personal.enable [
    pkgs.hmcl
    (pkgs.bottles.override { removeWarningPopup = true; })
  ];
}
