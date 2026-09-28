{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.lyrics;

  python = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);

  lyricsd = pkgs.writeShellApplication {
    name = "lyricsd";
    text = ''
      export LYRICS_STATE_DIR=${lib.escapeShellArg cfg.stateDir}
      export LYRICS_WAYBAR_SIGNAL=${toString cfg.waybarSignal}
      export LYRICS_LEAD=${toString cfg.lead}
      exec ${lib.getExe python} ${./lyricsd.py} "$@"
    '';
  };
in
{
  options.custom.lyrics = {
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "lyrics";
      description = "Directory under $XDG_RUNTIME_DIR where lyricsd publishes track.json and line.json.";
    };
    waybarSignal = lib.mkOption {
      type = lib.types.ints.between 1 20;
      default = 10;
      description = "Waybar custom module signal (SIGRTMIN+N) sent when the current lyric line changes.";
    };
    lead = lib.mkOption {
      type = lib.types.float;
      default = 0.3;
      description = "Seconds each lyric line is shown ahead of its timestamp.";
    };
  };

  config.systemd.user.services.lyricsd = {
    Unit = {
      Description = "Synced lyrics for the active MPRIS player";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe lyricsd;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
