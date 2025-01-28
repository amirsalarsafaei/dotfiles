{ ... }:
{
  ######################################################################
  # Systemd Service: "vps-dbbackup.service"                             #
  # This service will SSH into "vps" (as configured in your ~/.ssh/config),
  # run pg_dump there (database name = amirsalarsafaeicom, user = amirsalarsafaeicom),
  # compress it, and store the backup SQL in /root/backups inside this machine. #
  ######################################################################
  systemd.user.services."vps-dbbackup" = {
    Unit.Description = "Backup the VPS Postgres Database to local system";
    Install.WantedBy = [ "multi-user.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = ''
        BACKUP_DIR="/root/backups"
        mkdir -p "$BACKUP_DIR"

        ssh vps "pg_dump -U amirsalarsafaeicom amirsalarsafaeicom" \
          | gzip > "$BACKUP_DIR/vps-dbbackup-$(date '+%Y-%m-%d_%H-%M-%S').sql.gz"
      '';
    };
  };

  ###########################################################################
  # Systemd Timer: "vps-dbbackup.timer"                                     #
  # Runs the "vps-dbbackup.service" on a schedule (daily, in this example). #
  ###########################################################################
  systemd.user.timers."vps-dbbackup" = {
    description = "Periodic daily backup of VPS DB";
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "daily"; # Runs once per day
    timerConfig.Persistent = true; # Catch up missed runs if machine was off
    unitConfig.Description = "Run daily backup of VPS DB";
  };
}
