{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  theme = config.custom.theme.resolved;
  t = theme.colors;
  s = theme.surfaces;
  a = theme.accents;
  cmd = config.custom.keys.commands;
  quickshell = lib.getExe config.programs.quickshell.package;
  fingerprint = osConfig.services.fprintd.enable or false;

  hex = color: lib.removePrefix "#" color;
  argb = alpha: color: "#${alpha}${hex color}";

  cavaConfig = pkgs.writeText "sidebar-cava.conf" ''
    [general]
    framerate = 40
    bars = 32
    autosens = 1

    [input]
    method = pulse
    source = auto

    [output]
    method = raw
    channels = mono
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 100
    bar_delimiter = 59
    frame_delimiter = 10

    [smoothing]
    monstercat = 1
    noise_reduction = 70
  '';

  stats = pkgs.writeShellApplication {
    name = "sidebar-stats";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      prev_total=0
      prev_idle=0
      while :; do
        read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
        busy_idle=$((idle + iowait))
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        cpu=0
        if [ "$prev_total" -gt 0 ] && [ "$total" -gt "$prev_total" ]; then
          delta=$((total - prev_total))
          cpu=$(((100 * (delta - (busy_idle - prev_idle))) / delta))
        fi
        prev_total=$total
        prev_idle=$busy_idle

        mem=$(awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { avail = $2 } END { printf "%d", (total - avail) * 100 / total }' /proc/meminfo)
        temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -n 1 || true)
        temp=$(( ''${temp:-0} / 1000 ))
        disk=$(df --output=pcent / | tail -n 1 | tr -dc '0-9')
        battery=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1 || true)
        status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1 || true)

        echo "$cpu $mem $temp ''${disk:-0} ''${battery:--1} ''${status:-none}"
        sleep 2
      done
    '';
  };

  action = pkgs.writeShellApplication {
    name = "sidebar-action";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.procps
      pkgs.systemd
      pkgs.networkmanager
      pkgs.bluez
      pkgs.brightnessctl
      pkgs.jcal
      pkgs.libnotify
      config.services.swaync.package
    ];
    text = ''
      blur_off="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-react/off"

      user_active() {
        systemctl --user is-active --quiet "$1"
      }

      case "''${1:-}" in
        states)
          wifi=0
          [ "$(timeout 2 nmcli radio wifi 2>/dev/null || true)" = enabled ] && wifi=1
          bluetooth=0
          timeout 2 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && bluetooth=1
          dnd=0
          [ "$(timeout 2 swaync-client -D 2>/dev/null || true)" = true ] && dnd=1
          night=0
          user_active hyprsunset.service && night=1
          caffeine=0
          user_active caffeine.service && caffeine=1
          blur=1
          [ -e "$blur_off" ] && blur=0
          echo "$wifi $bluetooth $dnd $night $caffeine $blur"
          ;;
        info)
          jdate '+%d %B %Y' 2>/dev/null || echo
          read -r seconds _ < /proc/uptime
          seconds=''${seconds%.*}
          days=$((seconds / 86400))
          hours=$((seconds % 86400 / 3600))
          minutes=$((seconds % 3600 / 60))
          if [ "$days" -gt 0 ]; then
            echo "''${days}d ''${hours}h"
          elif [ "$hours" -gt 0 ]; then
            echo "''${hours}h ''${minutes}m"
          else
            echo "''${minutes}m"
          fi
          brightnessctl -m -c backlight 2>/dev/null | cut -d, -f4 | tr -d '%' | grep . || echo -1
          ;;
        brightness)
          brightnessctl -q -c backlight set "''${2:?percent}%"
          ;;
        caps)
          state=0
          for led in /sys/class/leds/*capslock*/brightness; do
            [ "$(cat "$led" 2>/dev/null || echo 0)" = 1 ] && state=1
          done
          echo "$state"
          ;;
        wifi)
          if [ "$(nmcli radio wifi)" = enabled ]; then nmcli radio wifi off; else nmcli radio wifi on; fi
          ;;
        bluetooth)
          if bluetoothctl show | grep -q 'Powered: yes'; then bluetoothctl power off; else bluetoothctl power on; fi
          ;;
        dnd)
          swaync-client -d -sw >/dev/null
          ;;
        night)
          if user_active hyprsunset.service; then
            systemctl --user stop hyprsunset.service
          else
            systemctl --user start hyprsunset.service
          fi
          ;;
        caffeine)
          systemctl --user start hypridle.service
          if user_active caffeine.service; then
            systemctl --user stop caffeine.service
            notify-send -t 2000 "Caffeine" "Idle timers back on"
          else
            systemd-run --user --quiet --collect --unit=caffeine \
              ${lib.getExe' pkgs.systemd "systemd-inhibit"} --what=idle --who=Caffeine \
              --why="Caffeine toggle" --mode=block ${lib.getExe' pkgs.coreutils "sleep"} infinity
            notify-send -t 2000 "Caffeine" "Screen stays awake"
          fi
          ;;
        blur)
          ${cmd.wallpaperBlurToggle}
          ;;
        lock)
          loginctl lock-session
          ;;
        suspend)
          systemctl suspend
          ;;
        logout)
          uwsm stop
          ;;
        reboot)
          systemctl reboot
          ;;
        poweroff)
          systemctl poweroff
          ;;
        *)
          echo "usage: sidebar-action <states|info|brightness N|caps|wifi|bluetooth|dnd|night|caffeine|blur|lock|suspend|logout|reboot|poweroff>" >&2
          exit 2
          ;;
      esac
    '';
  };

  pamModules = "${pkgs.linux-pam}/lib/security";

  pamDir = pkgs.runCommand "quickshell-pam" { } ''
    mkdir -p $out
    cat > $out/password <<EOF
    auth required ${pamModules}/pam_unix.so
    account required ${pamModules}/pam_unix.so
    EOF
    cat > $out/fingerprint <<EOF
    auth required ${osConfig.services.fprintd.package or pkgs.fprintd}/lib/security/pam_fprintd.so
    account required ${pamModules}/pam_unix.so
    EOF
  '';

  themeQml = pkgs.writeText "Theme.qml" ''
    pragma Singleton
    import QtQuick
    import Quickshell

    Singleton {
        readonly property color ink: "${s.ink}"
        readonly property color inkGlass: "${argb "e6" s.ink}"
        readonly property color raisedGlass: "${argb "99" s.raised}"
        readonly property color hover: "${argb "59" t.base02}"
        readonly property color line: "${s.line}"
        readonly property color fg: "${t.base05}"
        readonly property color fgBright: "${t.base07}"
        readonly property color muted: "${t.base04}"
        readonly property color faint: "${t.base03}"
        readonly property color primary: "${a.primary}"
        readonly property color secondary: "${a.secondary}"
        readonly property color heat: "${a.heat}"
        readonly property color warm: "${a.warm}"
        readonly property color danger: "${t.base08}"
        readonly property color good: "${t.base0B}"
        readonly property string sans: "${theme.fonts.sans}"
        readonly property string mono: "${theme.fonts.mono}"
        readonly property int radius: 14
        readonly property int topGap: 52

        function alpha(c: color, value: real): color {
            return Qt.rgba(c.r, c.g, c.b, value);
        }
    }
  '';

  sysQml = pkgs.writeText "Sys.qml" ''
    pragma Singleton
    import QtQuick
    import Quickshell

    Singleton {
        readonly property string stats: "${lib.getExe stats}"
        readonly property string action: "${lib.getExe action}"
        readonly property string cava: "${lib.getExe pkgs.cava}"
        readonly property string cavaConfig: "${cavaConfig}"
        readonly property string pamDir: "${pamDir}"
        readonly property bool fingerprint: ${lib.boolToString fingerprint}
        readonly property string wallpaper: "${theme.wallpaper}"
        readonly property string touch: "${lib.getExe' pkgs.coreutils "touch"}"
        readonly property string hyprctl: "${lib.getExe' pkgs.hyprland "hyprctl"}"
        readonly property string lyricsDir: "${config.custom.lyrics.stateDir}"
    }
  '';

  shaders =
    pkgs.runCommand "quickshell-shaders"
      {
        nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
      }
      ''
        mkdir -p $out
        for shader in ${./shaders}/*.frag; do
          qsb --qt6 -o "$out/$(basename "$shader").qsb" "$shader"
        done
      '';

  mkConfig =
    name: root:
    pkgs.runCommand "quickshell-${name}" { } ''
      mkdir -p $out/shaders
      cp ${./qml}/*.qml $out/
      rm -f $out/shell.qml
      cp ${root} $out/shell.qml
      cp ${themeQml} $out/Theme.qml
      cp ${sysQml} $out/Sys.qml
      cp ${shaders}/*.qsb $out/shaders/
    '';

  shellConfig = mkConfig "shell" ./qml/shell.qml;
  lockConfig = mkConfig "lock" ./lock/shell.qml;

  hyprlock = lib.getExe config.programs.hyprlock.package;

  lockScreen = pkgs.writeShellApplication {
    name = "lock-screen";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.procps
    ];
    text = ''
      runtime="''${XDG_RUNTIME_DIR:?}"
      exec 9>"$runtime/lock-screen.lock"
      flock -n 9 || exit 0
      if pidof hyprlock >/dev/null; then
        exit 0
      fi

      ready="$runtime/lock-screen.ready"
      rm -f "$ready"
      LOCK_READY="$ready" ${quickshell} -p ${lockConfig} &
      shell=$!

      for _ in $(seq 100); do
        [ -e "$ready" ] && break
        kill -0 "$shell" 2>/dev/null || break
        sleep 0.05
      done

      if [ ! -e "$ready" ]; then
        kill "$shell" 2>/dev/null || true
        wait "$shell" 2>/dev/null || true
        exec ${hyprlock}
      fi

      status=0
      wait "$shell" || status=$?
      rm -f "$ready"
      if [ "$status" -ne 0 ]; then
        exec ${hyprlock}
      fi
    '';
  };
in
{
  programs.quickshell = {
    enable = true;
    configs.shell = shellConfig;
    activeConfig = "shell";
    systemd.enable = true;
  };

  custom.keys.commands = {
    sidebarToggle = "${quickshell} -c shell ipc call sidebar toggle";
    widgetsToggle = "${quickshell} -c shell ipc call widgets toggle";
    lockScreen = lib.getExe lockScreen;
  };
}
