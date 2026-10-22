{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.android-tools
  ]
  ++ lib.optionals config.custom.personal.enable [
    pkgs.libimobiledevice
    pkgs.ifuse
    pkgs.platformio-core
    pkgs.esphome
    pkgs.esptool
  ];
}
