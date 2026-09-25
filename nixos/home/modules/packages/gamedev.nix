{ pkgs, currentHostname, ... }:
pkgs.lib.optionals (currentHostname == "g14") [
  # The editor's shader compiler links libtinfo.so.6, which the Hub's FHS
  # sandbox lacks by default.
  (pkgs.unityhub.override { extraLibs = ps: [ ps.ncurses ]; })
]
