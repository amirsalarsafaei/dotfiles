{ pkgs, ... }:

let
  tehranTime = pkgs.writeShellScriptBin "tehran-time" ''
    #!/usr/bin/env bash
    TZ=Asia/Tehran TZDIR=${pkgs.tzdata}/share/zoneinfo exec ${pkgs.coreutils}/bin/date "''${@:-+%H:%M}"
  '';

  oledSet = pkgs.writeShellScriptBin "oled-set" ''
    #!/usr/bin/env bash
    set -euo pipefail
    state="''${XDG_RUNTIME_DIR:-/tmp}/oled-display"
    panels() {
      hyprctl monitors -j \
        | jq -r '.[] | select(.name | startswith("eDP")) | "\(.name)|\(.width)x\(.height)@\(.refreshRate)|\(.x)x\(.y)|\(.scale)"'
    }
    case "''${1:-}" in
      on)
        if [ -s "$state" ]; then
          while IFS='|' read -r output mode position scale; do
            hyprctl eval "hl.monitor({ output = '$output', mode = '$mode', position = '$position', scale = '$scale', disabled = false, mirror = \"\" })" >/dev/null
          done < "$state"
        elif ! hyprctl monitors -j | jq -e '.[] | select(.name | startswith("eDP"))' >/dev/null; then
          output=$(hyprctl monitors all -j | jq -r '[.[] | select(.name | startswith("eDP"))][0].name // empty')
          if [ -z "$output" ]; then
            echo "No internal panel found" >&2
            exit 1
          fi
          hyprctl eval "hl.monitor({ output = '$output', mode = 'preferred', position = 'auto', scale = 'auto', disabled = false, mirror = \"\" })" >/dev/null
        fi
        notify-send "Internal Display" "Enabled"
        ;;
      off)
        pending=$(mktemp)
        panels > "$pending"
        if [ ! -s "$pending" ]; then
          rm -f "$pending"
          notify-send "Internal Display" "Already disabled"
          exit 0
        fi
        mv "$pending" "$state"
        while IFS='|' read -r output _ _ _; do
          hyprctl eval "hl.monitor({ output = '$output', disabled = true })" >/dev/null
        done < "$state"
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
    tehranTime
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
      today="$(${tehranTime}/bin/tehran-time +%F)"
      note="$dir/$today.md"

      mkdir -p "$dir"

      ensure_note() {
        if [ ! -f "$note" ]; then
          sed "s/{{date}}/$today/" "$vault/Templates/Daily note.md" > "$note"
        fi
      }

      add_task() {
        awk -v line="$1" '
          function flush() { for (; blanks > 0; blanks--) print "" }
          /^## / {
            if (today && !done) { if (!filled) print ""; print line; done = 1 }
            flush()
            today = index($0, "## 📅 Today") == 1
            filled = 0
            print
            next
          }
          /^[[:space:]]*$/ { blanks++; next }
          today && !done && /^- \[ \][[:space:]]*$/ { flush(); print line; done = 1; next }
          { flush(); print; if (today) filled = 1 }
          END { if (!done) { flush(); print line } }
        ' "$note" > "$note.tmp"
        mv "$note.tmp" "$note"
      }

      case "''${1:-}" in
        -e|--edit)
          ensure_note
          exec "''${EDITOR:-nvim}" "$note"
          ;;
        "")
          if [ -f "$note" ]; then
            grep -nE '^\s*- \[ \] *\S' "$note" || echo "No open tasks for $today."
          else
            echo "No daily note for $today yet. Add one with: td <task>"
          fi
          ;;
        *)
          ensure_note
          task="$*"
          add_task "$(printf -- '- [ ] %s ➕ %s' "$task" "$today")"
          notify-send -a Obsidian -i obsidian "Task added" "$task"
          ;;
      esac
    '')

    (writeShellScriptBin "oled-toggle" ''
      #!/usr/bin/env bash
      set -euo pipefail

      if hyprctl monitors -j | jq -e '.[] | select(.name | startswith("eDP"))' > /dev/null; then
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
