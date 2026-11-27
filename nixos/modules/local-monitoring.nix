{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.localMonitoring;
  collectNvidiaMetrics = builtins.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  options.custom.localMonitoring.enable = lib.mkEnableOption "the loopback-only Prometheus, exporters and Grafana stack";

  config = lib.mkIf cfg.enable {
    services = {
      prometheus = {
        exporters = {
          node = {
            enable = true;
            listenAddress = "127.0.0.1";
            disabledCollectors = [
              "arp"
              "btrfs"
              "drm"
              "edac"
              "entropy"
              "fibrechannel"
              "infiniband"
              "ipvs"
              "nfsd"
              "perf"
              "processes"
              "rapl"
              "schedstat"
              "selinux"
              "sockstat"
              "softnet"
              "timex"
              "udp_queues"
              "wifi"
              "xfs"
              "zfs"
            ];
          };

          nvidia-gpu = lib.mkIf collectNvidiaMetrics {
            enable = true;
            listenAddress = "127.0.0.1";
            port = 9835;
          };

          blackbox = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = 9115;
            configFile = ./prometheus/blackbox.yml;
          };

        };
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9090;
        globalConfig.scrape_interval = "15s";
        scrapeConfigs = [
          {
            job_name = "node_exporter";
            static_configs = [
              { targets = [ "localhost:9100" ]; }
            ];
          }
          {
            job_name = "blackbox_exporter";
            static_configs = [
              { targets = [ "localhost:9115" ]; }
            ];
          }

          {
            job_name = "llama-server";
            bearer_token = "sk-local";
            static_configs = [
              { targets = [ "localhost:18080" ]; }
            ];
          }
        ]
        ++ lib.optionals collectNvidiaMetrics [
          {
            job_name = "nvidia-gpu";
            static_configs = [
              { targets = [ "localhost:9835" ]; }
            ];
          }
        ]
        ++ [
          {
            job_name = "local-projects";
            file_sd_configs = [
              {
                files = [
                  "/etc/nixos/prometheus-targets/*.yml"
                  "/etc/nixos/prometheus-targets/*.yaml"
                ];
                refresh_interval = "1m";
              }
            ];
          }
        ];
      };

      grafana = {
        enable = true;
        settings = {
          server.http_port = 3000;
          server.http_addr = "127.0.0.1";
          database.url = "sqlite3:////var/lib/grafana/data/grafana.db?_time_format=sqlite";
          security.secret_key = "abc";
        };

        provision.datasources.settings.datasources = [
          {
            name = "Prometheus-System";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
            isDefault = true;
            jsonData = {
              scrapeInterval = "15s";
              queryTimeout = "60s";
            };
          }
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /etc/nixos/prometheus-targets 0775 root users - -"
    ];
  };
}
