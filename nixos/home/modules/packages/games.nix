{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optional config.custom.personal.enable pkgs.hmcl;
}
