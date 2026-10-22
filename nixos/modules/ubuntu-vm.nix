{ config, lib, ... }:
{
  options.custom.ubuntuVm.enable = lib.mkEnableOption "the shared Ubuntu VM managed with Incus";

  config = lib.mkIf config.custom.ubuntuVm.enable {
    virtualisation.incus = {
      enable = true;
      preseed = {
        networks = [
          {
            name = "ubuntu-br0";
            type = "bridge";
            config = {
              "ipv4.address" = "10.89.0.1/24";
              "ipv4.nat" = "true";
              "ipv6.address" = "none";
            };
          }
        ];
        storage_pools = [
          {
            name = "ubuntu";
            driver = "dir";
          }
        ];
        profiles = [
          {
            name = "ubuntu";
            config = {
              "limits.memory" = "4GiB";
              "limits.cpu" = "2";
              "boot.autostart" = "false";
            };
            devices = {
              root = {
                type = "disk";
                path = "/";
                pool = "ubuntu";
                size = "32GiB";
              };
              eth0 = {
                type = "nic";
                name = "eth0";
                network = "ubuntu-br0";
                "ipv4.address" = "10.89.0.2";
              };
            };
          }
        ];
      };
    };

    users.users.amirsalar.extraGroups = [ "incus-admin" ];
    networking = {
      nftables = {
        enable = true;
        flushRuleset = false;
      };
      firewall.interfaces.ubuntu-br0 = {
        allowedUDPPorts = [
          53
          67
        ];
        allowedTCPPorts = [ 53 ];
      };
    };
    boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;
    virtualisation.docker.daemon.settings."ip-forward-no-drop" = true;
  };
}
