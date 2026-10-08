{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.airpods;
  hardening = import ../../systemd/lib.nix { inherit lib; };
  airpods-tui = pkgs.callPackage ../../../../pkgs/airpods-tui.nix { };
  toml = pkgs.formats.toml { };

  daemonRuntime = "airpods-tui";

  status = pkgs.writeShellApplication {
    name = "airpods-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.socat
      airpods-tui
    ];
    text = ''
      runtime="''${XDG_RUNTIME_DIR:?}"
      socket="$runtime/${daemonRuntime}/airpods-tui.sock"
      dir="$runtime/${cfg.stateDir}"
      mkdir -p "$dir"

      tries=0
      until socat -u OPEN:/dev/null "UNIX-CONNECT:$socket" 2>/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -lt 100 ] || exit 1
        sleep 0.1
      done

      XDG_RUNTIME_DIR="$runtime/${daemonRuntime}" airpods-tui --waybar-watch | while IFS= read -r line; do
        printf '%s\n' "$line" >"$dir/status.json.tmp"
        mv -f "$dir/status.json.tmp" "$dir/status.json"
      done
    '';
  };
in
{
  options.custom.airpods.stateDir = lib.mkOption {
    type = lib.types.str;
    default = "airpods";
    description = "Directory under $XDG_RUNTIME_DIR where airpods-status publishes status.json.";
  };

  config = {
    home.packages = [ airpods-tui ];

    custom.sessionBusProxy.airpods-tui = {
      services = [ "airpods-tui" ];
      talk = [ "org.freedesktop.Notifications" ];
      call = hardening.mprisCalls (
        map (method: "org.mpris.MediaPlayer2.Player.${method}") [
          "Play"
          "Pause"
          "PlayPause"
          "Next"
          "Previous"
        ]
      );
      broadcast = hardening.mprisSignals;
    };

    xdg.configFile."airpods-tui/config.toml".source = toml.generate "airpods-tui-config.toml" {
      volume_osd_command = [ ];
      volume_set_command = [
        (lib.getExe' pkgs.wireplumber "wpctl")
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "{}"
      ];
      battery_alert_command = [
        (lib.getExe pkgs.libnotify)
        "AirPods"
        "{}"
      ];
      ble_scan = true;
      auto_connect = true;
    };

    systemd.user = {
      tmpfiles.rules = [
        "d %t/${cfg.stateDir} 0700 - - -"
        "d %h/.local/share/airpods-tui 0700 - - -"
      ];

      services = {
        airpods-tui = {
          Unit = {
            Description = "AirPods TUI daemon";
            After = [
              "bluetooth.target"
              "graphical-session.target"
            ];
            PartOf = [ "graphical-session.target" ];
            Upholds = [ "airpods-status.service" ];
          };
          Service = lib.mkMerge [
            hardening.user
            {
              ExecStartPre = "+${lib.getExe' pkgs.coreutils "ln"} -sfn %t/${daemonRuntime}/airpods-tui.sock %t/airpods-tui.sock";
              ExecStart = "${lib.getExe airpods-tui} --daemon";
              Restart = "on-failure";
              RestartSec = 5;
              Environment = [
                "XDG_RUNTIME_DIR=%t/${daemonRuntime}"
                "PULSE_SERVER=unix:%t/pulse/native"
                "PIPEWIRE_RUNTIME_DIR=%t"
              ];
              RuntimeDirectory = [ daemonRuntime ];
              RuntimeDirectoryMode = "0700";
              BindPaths = [ "%h/.local/share/airpods-tui" ];
              BindReadOnlyPaths = [
                "%h/.config/airpods-tui"
                "-%t/pulse"
                "-%t/pipewire-0"
              ];
              RestrictAddressFamilies = [ "AF_BLUETOOTH" ];
            }
          ];
          Install.WantedBy = [ "graphical-session.target" ];
        };

        airpods-status = {
          Unit = {
            Description = "AirPods status for the Quickshell bar";
            BindsTo = [ "airpods-tui.service" ];
            After = [ "airpods-tui.service" ];
          };
          Service = lib.mkMerge [
            hardening.user
            {
              ExecStart = lib.getExe status;
              ExecStopPost = "+${lib.getExe' pkgs.coreutils "rm"} -f %t/${cfg.stateDir}/status.json %t/${cfg.stateDir}/status.json.tmp";
              Restart = "on-failure";
              RestartSec = 2;
              RuntimeDirectory = [ cfg.stateDir ];
              RuntimeDirectoryMode = "0700";
              RuntimeDirectoryPreserve = "yes";
              BindReadOnlyPaths = [
                "%t/${daemonRuntime}"
                "-%h/.config/airpods-tui"
              ];
              InaccessiblePaths = [ "/run/dbus" ];
              PrivateNetwork = true;
            }
          ];
        };
      };
    };
  };
}
