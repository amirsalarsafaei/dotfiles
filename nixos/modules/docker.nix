{ config, lib, ... }:
{
  config = lib.mkIf config.virtualisation.docker.enable {
    virtualisation.docker.daemon.settings = {
      bip = "192.168.143.1/24";
      default-address-pools = [
        {
          base = "192.168.144.0/20";
          size = 24;
        }
      ];
    };
    users.users.amirsalar.extraGroups = [ "docker" ];
  };
}
