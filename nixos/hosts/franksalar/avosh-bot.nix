{ config, lib, ... }:
let
  cfg = config.custom.avoshBot;

  container = {
    image = "ghcr.io/avosh-clinic/avosh-bot:latest";
    pull = "newer";
    volumes = [ "${cfg.dataDir}:/data" ];
    environment = {
      DJANGO_DEBUG = "False";
      PLAN_DAYS = "7";
      AI_BASE_URL = "https://api.gapgpt.app/v1";
      AI_MODEL = "gpt-5.5";
      AI_TEMPERATURE = "0.2";
      AI_INTAKE_ENABLED = "True";
      AI_INTAKE_PUBLIC = "False";
      DEVELOPER_TELEGRAM_IDS = "176161958";
      MINIAPP_URL = "https://diet.amirsalarsafaei.com";
    };
    environmentFiles = [ "/etc/avosh-bot.env" ];
    login = {
      registry = "ghcr.io";
      username = "amirsalarsafaei";
      passwordFile = "/etc/avosh-bot-ghcr-token";
    };
  };
in
{
  options.custom.avoshBot = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/avosh-bot";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8010;
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "avosh";
    };
  };

  config = {
    users.groups.${cfg.group}.gid = 10001;

    systemd.tmpfiles.settings."10-avosh-bot".${cfg.dataDir}.d = {
      user = "10001";
      inherit (cfg) group;
      mode = "0750";
    };

    virtualisation.oci-containers.containers = {
      avosh-bot-web = container // {
        cmd = [ "web" ];
        ports = [ "127.0.0.1:${toString cfg.port}:8010" ];
      };

      avosh-bot-bot = container // {
        cmd = [ "bot" ];
        dependsOn = [ "avosh-bot-web" ];
      };
    };
  };
}
