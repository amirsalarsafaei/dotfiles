{
  config,
  lib,
  pkgs,
  ...
}:
let
  planner = config.custom.claudeCode.planner.enable;
  hardening = import ../../../systemd/lib.nix { inherit lib; };

  network = [
    "AF_INET"
    "AF_INET6"
  ];

  agendaSandbox = {
    CacheDirectory = [ "agenda-os" ];
    CacheDirectoryMode = "0700";
    BindPaths = [ "%h/.local/share/gcalcli" ];
    BindReadOnlyPaths = [
      "-%h/.config/gcalcli"
      "-%h/Documents/amirsalar-vault"
    ];
    InaccessiblePaths = [ "/run/dbus" ];
    RestrictAddressFamilies = network;
  };

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
      export AGENDA_BUSCTL=${lib.getExe' pkgs.systemd "busctl"}
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

  custom.sessionBusProxy = {
    agenda = {
      services = [
        "agenda-refresh"
        "agenda-remind"
        "agenda-day"
      ];
      talk = [ "org.freedesktop.Notifications" ];
    };

    agenda-mcp = lib.mkIf planner {
      services = [ "agenda-mcp@" ];
      call = [
        "org.freedesktop.systemd1=org.freedesktop.systemd1.Manager.StartUnit@/org/freedesktop/systemd1"
      ];
    };
  };

  systemd.user = {
    tmpfiles.rules = [ "d %h/.local/share/gcalcli 0700 - - -" ];

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
        Service = lib.mkMerge [
          hardening.user
          {
            ExecStart = lib.getExe mcpServer;
            StandardInput = "socket";
            StandardOutput = "socket";
            StandardError = "journal";
            BindReadOnlyPaths = [ "-%h/.local/share/gcalcli" ];
            InaccessiblePaths = [ "/run/dbus" ];
            RestrictAddressFamilies = network;
          }
        ];
      };

      agenda-refresh = {
        Unit = {
          Description = "Refresh today's agenda and send upcoming event reminders";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = lib.mkMerge [
          hardening.user
          agendaSandbox
          {
            Type = "oneshot";
            ExecStart = "${lib.getExe agenda} update";
          }
        ];
      };

      agenda-remind = {
        Unit = {
          Description = "Send reminders for agenda events starting soon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = lib.mkMerge [
          hardening.user
          agendaSandbox
          {
            Type = "oneshot";
            ExecStart = "${lib.getExe agenda} remind";
          }
        ];
      };

      agenda-day = {
        Unit = {
          Description = "Show today's agenda once each morning";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = lib.mkMerge [
          hardening.user
          agendaSandbox
          {
            Type = "oneshot";
            ExecStart = "${lib.getExe agenda} day";
          }
        ];
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
