{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.airpods;
  airpods-tui = pkgs.callPackage ../../../../pkgs/airpods-tui.nix { };
  toml = pkgs.formats.toml { };

  status = pkgs.writeShellApplication {
    name = "airpods-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.socat
      airpods-tui
    ];
    text = ''
      runtime="''${XDG_RUNTIME_DIR:?}"
      socket="$runtime/airpods-tui.sock"
      dir="$runtime/${cfg.stateDir}"
      mkdir -p "$dir"

      tries=0
      until socat -u OPEN:/dev/null "UNIX-CONNECT:$socket" 2>/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -lt 100 ] || exit 1
        sleep 0.1
      done

      airpods-tui --waybar-watch | while IFS= read -r line; do
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
      tmpfiles.rules = [ "d %t/${cfg.stateDir} 0700 - - -" ];

      services = {
        airpods-tui = {
          Unit = {
            Description = "AirPods TUI daemon";
            After = [ "bluetooth.target" ];
            Upholds = [ "airpods-status.service" ];
          };
          Service = {
            ExecStart = "${lib.getExe airpods-tui} --daemon";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };

        airpods-status = {
          Unit = {
            Description = "AirPods status for the Quickshell bar";
            BindsTo = [ "airpods-tui.service" ];
            After = [ "airpods-tui.service" ];
          };
          Service = {
            ExecStart = lib.getExe status;
            ExecStopPost = "${lib.getExe' pkgs.coreutils "rm"} -f %t/${cfg.stateDir}/status.json %t/${cfg.stateDir}/status.json.tmp";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };
      };
    };
  };
}
