{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.libimobiledevice
    pkgs.ifuse
    pkgs.android-tools
  ]
  ++ lib.optionals config.custom.personal.enable [
    pkgs.platformio-core
    pkgs.esphome
    pkgs.esptool
  ];
}
