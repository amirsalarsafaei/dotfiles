{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.mood;

  python = pkgs.python3.withPackages (ps: [ ps.pillow ]);

  moodd = pkgs.writeShellApplication {
    name = "moodd";
    text = ''
      export MOOD_STATE_DIR=${lib.escapeShellArg cfg.stateDir}
      export MOOD_PLAYERCTL=${lib.getExe pkgs.playerctl}
      exec ${lib.getExe python} ${./moodd.py} "$@"
    '';
  };
in
{
  options.custom.mood = {
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "mood";
      description = "Directory under $XDG_RUNTIME_DIR where moodd publishes palette.json, the accent colors taken from the playing track's album art.";
    };
  };

  config.systemd.user.services.moodd = {
    Unit = {
      Description = "Tint the desktop accents from the playing track's album art";
      After = [
        "playerctld.service"
        config.wayland.systemd.target
      ];
      Wants = [ "playerctld.service" ];
      PartOf = [ config.wayland.systemd.target ];
    };
    Service = {
      ExecStart = lib.getExe moodd;
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
