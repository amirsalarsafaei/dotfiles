{ config, ... }:
{
  services.spotifyd = {
    enable = config.custom.personal.enable;
    settings = {
      device_name = "mac-linux";
      device_type = "computer";
    };
  };
}
