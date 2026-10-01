{
  lib,
  pkgs,
  currentHostname,
  ...
}:
{
  home.packages = lib.optional (currentHostname == "g14") (
    pkgs.unityhub.override { extraLibs = ps: [ ps.ncurses ]; }
  );
}
