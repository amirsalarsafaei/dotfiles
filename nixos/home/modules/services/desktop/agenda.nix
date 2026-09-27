{
  config,
  lib,
  pkgs,
  ...
}:
let
  agenda = pkgs.writeShellApplication {
    name = "agenda-os";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      export AGENDA_GCALCLI=${lib.getExe pkgs.gcalcli}
      export AGENDA_NOTIFY_SEND=${lib.getExe pkgs.libnotify}
      exec ${lib.getExe pkgs.python3} ${./agenda.py} "$@"
    '';
  };
in
{
  home.packages = [ agenda ];

  custom.keys.commands.agendaShow = "${lib.getExe agenda} show";

  systemd.user = {
    services = {
      agenda-refresh = {
        Unit = {
          Description = "Refresh today's agenda and send upcoming event reminders";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe agenda} update";
        };
      };

      agenda-day = {
        Unit = {
          Description = "Show today's agenda once each morning";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe agenda} day";
        };
      };
    };

    timers = {
      agenda-refresh = {
        Unit.Description = "Refresh today's agenda every five minutes";
        Timer = {
          OnStartupSec = "45s";
          OnUnitActiveSec = "5m";
          Unit = "agenda-refresh.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      agenda-day = {
        Unit.Description = "Show today's agenda after login and each morning";
        Timer = {
          OnStartupSec = "2m";
          OnCalendar = "*-*-* 08:30:00";
          Persistent = true;
          Unit = "agenda-day.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
