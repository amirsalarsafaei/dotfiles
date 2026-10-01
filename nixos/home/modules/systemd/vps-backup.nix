{
  config,
  homeDir,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.custom.personal.enable {
  systemd.user.services."vps-dbbackup" = {
    Unit.Description = "Backup the VPS Postgres Database to local system";
    Install.WantedBy = [ "multi-user.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "backup-vps" ''
        export BACKUP_DIR="${homeDir}/backups"
        mkdir -p "$BACKUP_DIR"

        ssh finRoot "pg_dump -U amirsalarsafaeicom amirsalarsafaeicom" \
          | gzip > "$BACKUP_DIR/vps-dbbackup-$(date '+%Y-%m-%d_%H-%M-%S').sql.gz"
      ''}";
    };
  };

  systemd.user.timers."vps-dbbackup" = {
    Unit.Description = "Periodic daily backup of VPS DB";
    Install.WantedBy = [ "timers.target" ];
    Timer.OnCalendar = "daily";
    Timer.Persistent = true;
  };
}
