{
  config,
  hostname,
  lib,
  pkgs,
  secrets,
  ...
}:
lib.mkIf (!config.isWork) {
  services.tailscale = {
    enable = true;
    extraDaemonFlags = [ "--no-logs-no-support" ];
    extraUpFlags = [
      "--login-server"
      secrets.tailscale.loginServer
      "--hostname"
      hostname
      "--accept-routes"
    ];
  };

  systemd.services.tailscaled-autoconnect.serviceConfig.TimeoutStartSec = "5s";

  custom.homeNetwork = {
    ssids = [
      "Amir"
      "Amir-5G-VIP"
      "Amir-2G-VIP"
      "Amir-5G"
      "Amir-2G"
    ];
    mqtt = {
      host = "mq.amirpi.top";
      port = 31883;
    };
    envVars = {
      DOCKER_REGISTRY = "docker.amirpi.top";
      NPM_CONFIG_REGISTRY = "https://repos.amirpi.top/repository/npm-proxy/";
      GOPROXY = "https://repos.amirpi.top/repository/go-proxy/,direct";
      GONOSUMDB = "gitea.amirpi.top/*";
      GONOSUMCHECK = "gitea.amirpi.top/*";
      GOPRIVATE = "gitea.amirpi.top/*";
    };
  };

  services.udev.packages = [ pkgs.platformio-core.udev ];
}
