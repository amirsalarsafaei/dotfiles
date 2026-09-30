{ lib, osConfig, ... }:
{
  services.spotifyd = lib.mkIf (!(osConfig.isWork or false)) {
    enable = true;
    settings = {
      device_name = "mac-linux";
      device_type = "computer";
    };
  };
}
