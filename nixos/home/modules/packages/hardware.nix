{
  pkgs,
  isWork ? false,
  ...
}:
[
  pkgs.libimobiledevice
  pkgs.ifuse
  pkgs.android-tools
]
++ pkgs.lib.optionals (!isWork) [
  pkgs.platformio-core
  pkgs.esphome
  pkgs.esptool
]
