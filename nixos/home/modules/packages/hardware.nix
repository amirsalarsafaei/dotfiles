{ pkgs, personal, ... }:
[
  pkgs.libimobiledevice
  pkgs.ifuse
  pkgs.android-tools
]
++ pkgs.lib.optionals personal [
  pkgs.platformio-core
  pkgs.esphome
  pkgs.esptool
]
