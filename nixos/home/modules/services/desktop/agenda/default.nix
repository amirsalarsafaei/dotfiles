{
  config,
  lib,
  pkgs,
  ...
}:
let
  planner = config.custom.claudeCode.planner.enable;

  agenda = pkgs.writeShellApplication {
    name = "agenda-os";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      export AGENDA_GCALCLI=${lib.getExe pkgs.gcalcli}
      export AGENDA_NOTIFY_SEND=${lib.getExe pkgs.libnotify}
      export AGENDA_PKILL=${lib.getExe' pkgs.procps "pkill"}
      export AGENDA_OAUTH_CLIENT=${config.sops.secrets.google_calendar_oauth_client.path}
      export AGENDA_SELF="$0"
      exec ${lib.getExe pkgs.python3} ${./agenda.py} "$@"
    '';
  };

  mcpPython = pkgs.python3.withPackages (ps: [
    ps.google-auth
    ps.mcp
    ps.requests
  ]);

  mcpServer = pkgs.writeShellApplication {
    name = "agenda-mcp";
    text = ''
      export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
      export AGENDA_SYSTEMCTL=${config.systemd.user.systemctlPath}
      exec ${lib.getExe mcpPython} ${./agenda_mcp.py} "$@"
    '';
  };

  mcpSocket = "agenda/mcp.sock";

  mcpConnect = pkgs.writeShellApplication {
    name = "agenda-mcp-connect";
    text = ''
      exec ${lib.getExe pkgs.socat} STDIO "UNIX-CONNECT:''${XDG_RUNTIME_DIR:?}/${mcpSocket}"
    '';
  };

  mcpConfig = pkgs.writeText "agenda-mcp.json" (
    builtins.toJSON {
      mcpServers.calendar = {
        type = "stdio";
        command = lib.getExe mcpConnect;
      };
    }
  );
in
{
  sops.secrets.google_calendar_oauth_client = { };

  home.packages = [ agenda ];

  custom.keys.commands = {
    agendaShow = "${lib.getExe agenda} show";
    agendaDone = "${lib.getExe agenda} done";
  };

  custom.claudeCode.planner.mcpConfigs = lib.mkIf planner [ "${mcpConfig}" ];

  systemd.user = {
    sockets.agenda-mcp = lib.mkIf planner {
      Unit.Description = "Google Calendar MCP socket for Claude Code";
      Socket = {
        ListenStream = "%t/${mcpSocket}";
        Accept = true;
        SocketMode = "0600";
        DirectoryMode = "0700";
        MaxConnections = 32;
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    services = {
      "agenda-mcp@" = lib.mkIf planner {
        Unit.Description = "Google Calendar MCP server for one Claude Code session";
        Service = {
          ExecStart = lib.getExe mcpServer;
          StandardInput = "socket";
          StandardOutput = "socket";
          StandardError = "journal";
        };
      };

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

      agenda-remind = {
        Unit = {
          Description = "Send reminders for agenda events starting soon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe agenda} remind";
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
        Unit = {
          Description = "Refresh today's agenda every three minutes";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Timer = {
          OnActiveSec = "45s";
          OnUnitActiveSec = "3m";
          AccuracySec = "30s";
          Unit = "agenda-refresh.service";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      agenda-remind = {
        Unit = {
          Description = "Check for upcoming agenda events every minute";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Timer = {
          OnCalendar = "minutely";
          AccuracySec = "5s";
          Unit = "agenda-remind.service";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      agenda-day = {
        Unit = {
          Description = "Show today's agenda after login and each morning";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Timer = {
          OnActiveSec = "2m";
          OnCalendar = "*-*-* 08:30:00";
          Persistent = true;
          Unit = "agenda-day.service";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
