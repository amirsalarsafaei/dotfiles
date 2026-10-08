{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.mood;
  hardening = import ../../../systemd/lib.nix { inherit lib; };

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

  config.custom.sessionBusProxy.moodd = {
    services = [ "moodd" ];
    call = hardening.mprisCalls [ ];
    broadcast = hardening.mprisSignals;
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
    Service = lib.mkMerge [
      hardening.user
      {
        ExecStart = lib.getExe moodd;
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = [ cfg.stateDir ];
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
        CacheDirectory = [ "mood" ];
        CacheDirectoryMode = "0700";
        PrivateTmp = false;
        InaccessiblePaths = [
          "/run/dbus"
          "-/tmp/.X11-unix"
          "-/tmp/.ICE-unix"
        ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      }
    ];
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
