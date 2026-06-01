{
  config,
  lib,
  ...
}:

{
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    "net.ipv4.ip_forward" = 1;

    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";

    "net.core.rmem_default" = 262144;
    "net.core.wmem_default" = 262144;

    "net.core.somaxconn" = 8192;
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.ipv4.ip_local_port_range" = "1024 65535";

    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_syncookies" = 1;

    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_keepalive_probes" = 6;

    "net.ipv4.tcp_fastopen" = 0;
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_dsack" = 1;
    "net.ipv4.tcp_fack" = 1;

    # Optional: Increase maximum orphan sockets to prevent dropping connections during high load
    "net.ipv4.tcp_max_orphans" = 32768;
  };

  # These overrides only apply when the corresponding service is actually
  # enabled on the host. Guarding with mkIf avoids dangling systemd unit
  # definitions on hosts that don't enable them.
  systemd.services.xray = lib.mkIf config.services.xray.enable {
    serviceConfig = {
      LimitNOFILE = 1048576;
      LimitMEMLOCK = "infinity";
    };
  };

  systemd.services.nginx = lib.mkIf config.services.nginx.enable {
    serviceConfig = {
      LimitNOFILE = 1048576;
      LimitMEMLOCK = "infinity";
    };
  };
}
