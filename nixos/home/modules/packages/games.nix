{ pkgs, personal, ... }:
pkgs.lib.optionals personal [
  pkgs.hmcl
]
