{ pkgs, currentHostname, ... }:
pkgs.lib.optionals (currentHostname == "g14") [
  (pkgs.unityhub.override { extraLibs = ps: [ ps.ncurses ]; })
]
