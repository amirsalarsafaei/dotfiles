{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (!config.isWork) {
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
