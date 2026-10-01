{ pkgs, ... }:

let
  oledSet = pkgs.writeShellScriptBin "oled-set" ''
    #!/usr/bin/env bash
    set -euo pipefail
    case "''${1:-}" in
      on)
        hyprctl eval "hl.monitor({ output = 'eDP-1', mode = 'preferred', position = 'auto', scale = '1.6', disabled = false, mirror = \"\" })"
        notify-send "Internal Display" "Enabled"
        ;;
      off)
        hyprctl eval "hl.monitor({ output = 'eDP-1', disabled = true })"
        notify-send "Internal Display" "Disabled"
        ;;
      *)
        echo "Usage: oled-set {on|off}" >&2
        exit 1
        ;;
    esac
  '';

  oledPowerSync = pkgs.writeShellScriptBin "oled-power-sync" ''
    #!/usr/bin/env bash
    set -euo pipefail
    online=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0)
    if [ "$online" = "1" ]; then
      "${oledSet}/bin/oled-set" off
    else
      "${oledSet}/bin/oled-set" on
    fi
  '';
in

{
  systemd.user.services.oled-power-sync = {
    Unit.Description = "Sync internal OLED panel to AC power state";
    Service = {
      Type = "oneshot";
      ExecStart = "${oledPowerSync}/bin/oled-power-sync";
    };
  };

  home.packages = with pkgs; [
    oledSet
    oledPowerSync

    (writeShellScriptBin "volume" ''
      #!/usr/bin/env bash
      set -euo pipefail

      get_volume() {
        wpctl get-volume @DEFAULT_SINK@ | sed -e 's/[^0-9]*\([0-9]\+\)\.\([0-9]\+\)[^0-9]*/\1\2/g'
      }

      is_mute() {
        [[ "$(wpctl get-volume @DEFAULT_SINK@)" == *"MUTED"* ]]
      }

      send_notification() {
        if quickshell -c shell ipc call osd volume >/dev/null 2>&1; then
          return
        fi
        if is_mute; then
          notify-send "Muted"
        else
          notify-send -h int:value:"$(get_volume)" "Volume"
        fi
      }

      case "''${1:-}" in
        up)
          wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1
          send_notification
          ;;
        down)
          wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
          send_notification
          ;;
        mute)
          wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          if quickshell -c shell ipc call osd volume >/dev/null 2>&1; then
            :
          elif is_mute; then
            dunstify -i audio-volume-muted-panel -t 8000 -r 2593 -u normal "Mute"
          else
            send_notification
          fi
          ;;
        *)
          echo "Usage: volume {up|down|mute}" >&2
          exit 1
          ;;
      esac
    '')

    (writeShellScriptBin "brightness" ''
      #!/usr/bin/env bash
      set -euo pipefail

      case "''${1:-}" in
        up)
          set_to="+10%"
          ;;
        down)
          set_to="10%-"
          ;;
        *)
          echo "Usage: brightness {up|down}" >&2
          exit 1
          ;;
      esac

      mapfile -t devices < <(brightnessctl -l -m | awk -F',' '$2 == "backlight" {print $1}')

      for dev in "''${devices[@]}"; do
        brightnessctl -d "$dev" set "$set_to" > /dev/null
      done

      if [ "''${#devices[@]}" -gt 0 ]; then
        current=$(brightnessctl -d "''${devices[0]}" -m | cut -d',' -f4 | tr -d '%')
        quickshell -c shell ipc call osd brightness "$current" >/dev/null 2>&1 ||
          notify-send -h string:x-canonical-private-synchronous:brightness -h int:value:"$current" "Brightness: $current%"
      fi
    '')

    (writeShellScriptBin "td" ''
      #!/usr/bin/env bash
      set -euo pipefail

      vault="$HOME/Documents/amirsalar-vault"
      dir="$vault/daily notes"
      today="$(date +%Y-%m-%d)"
      note="$dir/$today.md"

      mkdir -p "$dir"

      ensure_note() {
        if [ ! -f "$note" ]; then
          printf '# %s\n\n## Tasks\n' "$today" > "$note"
        fi
      }

      case "''${1:-}" in
        -e|--edit)
          ensure_note
          exec "''${EDITOR:-nvim}" "$note"
          ;;
        "")
          if [ -f "$note" ]; then
            grep -nE '^\s*- \[ \]' "$note" || echo "No open tasks for $today."
          else
            echo "No daily note for $today yet. Add one with: td <task>"
          fi
          ;;
        *)
          ensure_note
          task="$*"
          printf -- '- [ ] %s ➕ %s\n' "$task" "$today" >> "$note"
          notify-send -a Obsidian -i obsidian "Task added" "$task"
          ;;
      esac
    '')

    (writeShellScriptBin "oled-toggle" ''
      #!/usr/bin/env bash
      set -euo pipefail

      if hyprctl monitors -j | jq -e '.[] | select(.name == "eDP-1")' > /dev/null; then
        "${oledSet}/bin/oled-set" off
      else
        "${oledSet}/bin/oled-set" on
      fi
    '')

    (writeShellScriptBin "kbdbacklight" ''
      #!/usr/bin/env bash
      set -euo pipefail

      case "''${1:-}" in
        up)
          set_to="+20%"
          ;;
        down)
          set_to="20%-"
          ;;
        *)
          echo "Usage: kbdbacklight {up|down}" >&2
          exit 1
          ;;
      esac

      kbd_dev=$(brightnessctl -l | grep -i kbd | head -1 | cut -d"'" -f2)

      if [ -z "$kbd_dev" ]; then
        notify-send "Keyboard Backlight" "No keyboard backlight found"
        exit 1
      fi

      brightnessctl -d "$kbd_dev" set "$set_to" > /dev/null
      current=$(brightnessctl -d "$kbd_dev" -m | cut -d',' -f4 | tr -d '%')
      notify-send -h int:value:"$current" "Keyboard Backlight"
    '')
  ];
}
