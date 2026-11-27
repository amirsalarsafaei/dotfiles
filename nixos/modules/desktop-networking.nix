{
  config,
  lib,
  pkgs,
  ...
}:
let
  hardening = import ../home/modules/systemd/lib.nix { inherit lib; };
in
{
  environment.etc.hosts.enable = false;

  systemd.services.local-hosts = {
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    restartTriggers = [ config.environment.etc.hosts.source ];
    serviceConfig = lib.mkMerge [
      hardening.system
      {
        Type = "oneshot";
        ReadWritePaths = [ "/etc" ];
        RestrictAddressFamilies = [ "none" ];
        ExecStart = pkgs.writeShellScript "update-local-hosts" ''
          if [[ ! -e /etc/hosts.local ]]; then
            install -m 0644 -o root -g root /dev/null /etc/hosts.local
          fi

          tmp="$(mktemp /etc/.hosts.XXXXXX)"
          trap 'rm -f "$tmp"' EXIT
          cat ${config.environment.etc.hosts.source} /etc/hosts.local > "$tmp"
          chmod 0644 "$tmp"
          chown root:root "$tmp"
          mv "$tmp" /etc/hosts
          trap - EXIT
        '';
      }
    ];
  };

  systemd.paths.local-hosts = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = "/etc/hosts.local";
  };

  programs.openvpn3.enable = true;

  networking = {
    networkmanager = {
      enable = true;
      wifi = {
        backend = "iwd";
        powersave = false;
      };
      plugins = with pkgs; [
        networkmanager-openconnect
        networkmanager-openvpn
      ];
      dns = "systemd-resolved";
      settings = {
        logging = {
          level = "INFO";
          domains = "ALL";
        };
      };
    };
    wireless.enable = false;
    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = false;
          AddressRandomization = "disabled";
        };
        Network = {
          ConnectTimeout = 120;
        };
        Settings = {
          AutoConnect = true;
        };
        DriverQuirks = {
          PowerSaveDisable = "*";
        };
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      checkReversePath = "loose";
      logRefusedConnections = true;
      logRefusedPackets = true;
    };
    nftables.enable = true;
  };
  services.resolved = {
    enable = true;
    settings.Resolve = {
      FallbackDNS = [
        "8.8.8.8"
        "8.8.4.4"
      ];
      LLMNR = "no";
    };
  };

}
