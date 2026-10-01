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
  quickshell = lib.getExe config.programs.quickshell.package;
  fingerprint = osConfig.services.fprintd.enable or false;
  compactOutput = lib.defaultTo "" (osConfig.hyprland.compactOutput or null);
  powerProfiles = osConfig.services.power-profiles-daemon.enable or false;

  hex = color: lib.removePrefix "#" color;
  argb = alpha: color: "#${alpha}${hex color}";

  mkCavaConfig =
    name: framerate: bars:
    pkgs.writeText name ''
      [general]
      framerate = ${toString framerate}
      bars = ${toString bars}
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

  cavaConfig = mkCavaConfig "sidebar-cava.conf" 40 32;
  cavaBarConfig = mkCavaConfig "bar-cava.conf" 30 12;

  barProbe = pkgs.writeShellApplication {
    name = "bar-probe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      thermal=""
      for hw in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hw/name" 2>/dev/null || true)
        case "$name" in
          coretemp | k10temp | zenpower)
            if [ -r "$hw/temp1_input" ]; then
              thermal="$hw/temp1_input"
              break
            fi
            ;;
        esac
      done
      if [ -z "$thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*; do
          if [ "$(cat "$zone/type" 2>/dev/null || true)" = x86_pkg_temp ]; then
            thermal="$zone/temp"
            break
          fi
        done
      fi
      if [ -z "$thermal" ] && [ -r /sys/class/thermal/thermal_zone0/temp ]; then
        thermal=/sys/class/thermal/thermal_zone0/temp
      fi
      echo "$thermal"
      ${lib.getExe' pkgs.hyprland "hyprctl"} devices -j 2>/dev/null \
        | jq -r '([.keyboards[] | select(.main)][0] // .keyboards[0] // {}).active_keymap // ""' \
        || echo
      gpu=""
      for card in /sys/class/drm/card[0-9]; do
        if [ -r "$card/device/gpu_busy_percent" ]; then
          gpu="busy $card/device/gpu_busy_percent"
          break
        fi
        for idle in "$card/gt/gt0/rc6_residency_ms" "$card/device/tile0/gt0/gtidle/idle_residency_ms"; do
          if [ -r "$idle" ]; then
            gpu="idle $idle"
            break 2
          fi
        done
      done
      echo "$gpu"
    '';
  };

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
          echo "$wifi $bluetooth $dnd $night $caffeine"
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
          echo "usage: sidebar-action <states|info|brightness N|caps|wifi|bluetooth|dnd|night|caffeine|lock|suspend|logout|reboot|poweroff>" >&2
          exit 2
          ;;
      esac
    '';
  };

  agentsPick = pkgs.writeShellApplication {
    name = "agents-pick";
    text = ''
      exec ${quickshell} -c shell ipc call sidebar agents
    '';
  };

  agents = pkgs.writeShellApplication {
    name = "wall-agents";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.jq
      pkgs.util-linux
      config.programs.zellij.package
    ];
    text = ''
      hyprctl=${lib.getExe' pkgs.hyprland "hyprctl"}

      sessions() {
        { zellij list-sessions -n 2>/dev/null || true; } | awk '/\[Created/ && !/EXITED/ { print $1 }'
      }

      clients() {
        { timeout 2 zellij -s "$1" action list-clients 2>/dev/null || true; } | tail -n +2 | grep -c . || true
      }

      focus() {
        local tab
        tab=$(timeout 2 zellij -s "$1" action list-panes -j 2>/dev/null \
          | jq -r --argjson id "$2" 'first(.[] | select((.is_plugin | not) and .id == $id) | .tab_id) // empty') || tab=""
        [ -n "$tab" ] || return 0
        timeout 2 zellij -s "$1" action go-to-tab-by-id "$tab" || true
        timeout 2 zellij -s "$1" action focus-pane-id "terminal_$2" || true
      }

      case "''${1:-}" in
        live)
          sessions | while read -r session; do
            { timeout 2 zellij -s "$session" action list-panes -j -a 2>/dev/null || true; } \
              | jq -c --arg session "$session" '
                  .[]?
                  | select((.is_plugin | not) and (.exited | not) and ((.pane_command // "") | test("/bin/claude( |$)")))
                  | {key: "\($session)/\(.id)", value: {session: $session, pane: (.id | tostring), tab: (.tab_name // ""), title: (.title // ""), cwd: (.pane_cwd // "")}}' \
              || true
          done | jq -cs 'from_entries'
          ;;
        open)
          session=''${2:?session}
          pane=''${3:?pane}
          case "$pane" in
            "" | *[!0-9]*) exit 2 ;;
          esac
          running=$(sessions)
          grep -qxF -- "$session" <<<"$running" || exit 0
          window=$("$hyprctl" clients -j \
            | jq -r --arg session "$session" '
                [.[] | select(.title == $session or (.title | startswith($session + " | ")))]
                | sort_by(.focusHistoryID) | first | .address // empty') || window=""
          if [ -n "$window" ]; then
            for _ in $(seq 20); do
              "$hyprctl" dispatch focuswindow "address:$window" >/dev/null
              [ "$("$hyprctl" activewindow -j | jq -r '.address // empty')" = "$window" ] && break
              sleep 0.05
            done
          else
            before=$(clients "$session")
            setsid -f ${lib.getExe (osConfig.programs.uwsm.package or pkgs.uwsm)} app -- \
              ${lib.getExe config.programs.ghostty.package} -e ${lib.getExe config.programs.zellij.package} attach "$session" >/dev/null 2>&1
            for _ in $(seq 60); do
              sleep 0.1
              [ "$(clients "$session")" -gt "$before" ] && break
            done
          fi
          focus "$session" "$pane"
          ;;
        *)
          echo "usage: wall-agents <live|open SESSION PANE>" >&2
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
    import Quickshell.Io

    Singleton {
        id: theme

        property var mood: ({
                active: false
            })

        readonly property color basePrimary: "${a.primary}"
        readonly property color baseSecondary: "${a.secondary}"

        readonly property color ink: "${s.ink}"
        readonly property color inkGlass: "${argb "f5" s.ink}"
        readonly property color raisedGlass: "${argb "ff" s.raised}"
        readonly property color hover: "${argb "59" t.base02}"
        readonly property color line: "${s.line}"
        readonly property color fg: "${t.base05}"
        readonly property color fgBright: "${t.base07}"
        readonly property color muted: "${t.base04}"
        readonly property color faint: "${t.base03}"
        readonly property color blue: "${t.base0D}"
        readonly property color cyan: "${t.base0C}"
        readonly property color yellow: "${t.base0A}"
        property color primary: mood.active ? mood.primary : basePrimary
        property color secondary: mood.active ? mood.secondary : baseSecondary

        Behavior on primary {
            ColorAnimation {
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on secondary {
            ColorAnimation {
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }

        FileView {
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/${config.custom.mood.stateDir}/palette.json"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                try {
                    theme.mood = JSON.parse(text());
                } catch (error) {
                    theme.mood = {
                        active: false
                    };
                }
            }
            onLoadFailed: theme.mood = {
                active: false
            }
        }

        readonly property color heat: "${a.heat}"
        readonly property color warm: "${a.warm}"
        readonly property color danger: "${t.base08}"
        readonly property color good: "${t.base0B}"
        readonly property string sans: "${theme.fonts.sans}"
        readonly property string display: "${theme.fonts.display}"
        readonly property string mono: "${theme.fonts.mono}"
        readonly property string serif: "${config.stylix.fonts.serif.name}"
        readonly property string persian: "Vazirmatn"
        readonly property int radius: 14
        readonly property int topGap: 52
        readonly property int quick: 120
        readonly property int brisk: 200
        readonly property int calm: 320
        readonly property int ambient: 1400
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var drift: [0.37, 0, 0.63, 1, 1, 1]
        readonly property var enter: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var exit: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property real pressScale: 0.95

        function alpha(c: color, value: real): color {
            return Qt.rgba(c.r, c.g, c.b, value);
        }

        function fontFor(text: string, fallback: string): string {
            return /[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/.test(text) ? persian : fallback;
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
        readonly property string cavaBarConfig: "${cavaBarConfig}"
        readonly property string barProbe: "${lib.getExe barProbe}"
        readonly property string systemctl: "${lib.getExe' pkgs.systemd "systemctl"}"
        readonly property string swaync: "${lib.getExe' config.services.swaync.package "swaync-client"}"
        readonly property string compactOutput: "${compactOutput}"
        readonly property bool powerProfiles: ${lib.boolToString powerProfiles}
        readonly property string pamDir: "${pamDir}"
        readonly property bool fingerprint: ${lib.boolToString fingerprint}
        readonly property string wallpaper: "${theme.wallpaper}"
        readonly property string touch: "${lib.getExe' pkgs.coreutils "touch"}"
        readonly property string hyprctl: "${lib.getExe' pkgs.hyprland "hyprctl"}"
        readonly property string lyricsDir: "${config.custom.lyrics.stateDir}"
        readonly property string agentsDir: "${config.custom.claudeCode.agentStatus.dir}"
        readonly property string agents: "${lib.getExe agents}"
        readonly property string airpodsDir: "${config.custom.airpods.stateDir}"
        readonly property string uwsm: "${lib.getExe (osConfig.programs.uwsm.package or pkgs.uwsm)}"
        readonly property string terminal: "${lib.getExe config.programs.ghostty.package}"
        readonly property string user: "${config.home.username}"
        readonly property string host: "${osConfig.networking.hostName or "nixos"}"
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
    pkgs.runCommand "quickshell-${name}"
      {
        nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
      }
      ''
        mkdir -p $out/shaders $out/textures
        cp ${./qml}/*.qml $out/
        rm -f $out/shell.qml
        cp ${root} $out/shell.qml
        cp ${themeQml} $out/Theme.qml
        cp ${sysQml} $out/Sys.qml
        cp ${shaders}/*.qsb $out/shaders/
        cp ${./assets}/*.jpg $out/textures/

        export HOME=$TMPDIR
        lint=$TMPDIR/lint
        cp -r $out $lint
        chmod -R u+w $lint
        cd $lint
        {
          echo "module Shell"
          for file in *.qml; do
            if grep -q "^pragma Singleton" "$file"; then
              echo "singleton ''${file%.qml} 1.0 $file"
            else
              echo "''${file%.qml} 1.0 $file"
            fi
          done
        } > qmldir
        levels=()
        for category in $(qmllint --help | grep -oE '^ +--[a-z-]+ <level>' | awk '{ print $1 }'); do
          if [ "$category" = --import ]; then
            levels+=("$category" warning)
          else
            levels+=("$category" disable)
          fi
        done
        qmllint -W 0 \
          -I ${config.programs.quickshell.package}/lib/qt-6/qml \
          -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
          -I . \
          "''${levels[@]}" *.qml
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
      pkgs.systemd
    ];
    text = ''
      runtime="''${XDG_RUNTIME_DIR:?}"
      exec 9>"$runtime/lock-screen.lock"
      flock -n 9 || exit 0
      if pidof hyprlock >/dev/null; then
        exit 0
      fi

      systemctl --user start --no-block quip.service || true

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

  systemd.user.services.quickshell = {
    Unit = {
      PartOf = [ config.programs.quickshell.systemd.target ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [ "${shellConfig}" ];
    };
    Service.RestartSec = 2;
  };

  custom.claudeCode.agentStatus.enable = true;

  custom.keys.commands = {
    barToggle = "${quickshell} -c shell ipc call bar toggle";
    barShow = "${quickshell} -c shell ipc call bar show";
    barHide = "${quickshell} -c shell ipc call bar hide";
    perfCycle = "${quickshell} -c shell ipc call perf cycle";
    skyToggle = "${quickshell} -c shell ipc call sky toggle";
    lyricsToggle = "${quickshell} -c shell ipc call lyrics toggle";
    sidebarToggle = "${quickshell} -c shell ipc call sidebar toggle";
    widgetsToggle = "${quickshell} -c shell ipc call widgets toggle";
    agentsPick = lib.getExe agentsPick;
    lockScreen = lib.getExe lockScreen;
  };
}
