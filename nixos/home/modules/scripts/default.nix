{ pkgs, ... }:

let
  oledSet = pkgs.writeShellScriptBin "oled-set" ''
    #!/usr/bin/env bash
    set -euo pipefail
    case "''${1:-}" in
      on)
        hyprctl keyword monitor "eDP-1,preferred,auto,1.6"
        notify-send "Internal Display" "Enabled"
        ;;
      off)
        hyprctl keyword monitor "eDP-1,disable"
        notify-send "Internal Display" "Disabled"
        ;;
      *)
        echo "Usage: oled-set {on|off}" >&2
        exit 1
        ;;
    esac
  '';

  # AC-power-driven policy: plugged in -> assume desk/dual-monitor use, spare
  # the OLED; unplugged -> assume laptop-only use, bring it back. Runs inside
  # the user's own systemd session (started via `systemctl --user`, see the
  # udev rule in the g14 host config) so it inherits the same PATH/env as a
  # normal shell — no root/Wayland-socket plumbing needed.
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
          if is_mute; then
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
        notify-send -h string:x-canonical-private-synchronous:brightness -h int:value:"$current" "Brightness: $current%"
      fi
    '')

    # td — capture a task into today's Obsidian daily note from the terminal.
    #   td buy milk        -> appends "- [ ] buy milk ➕ <today>" to today's note
    #   td                 -> lists today's open tasks
    #   td -e              -> opens today's note in $EDITOR
    # Format matches the obsidian-tasks plugin (➕ = created date).
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
            # Show today's open tasks, numbered.
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

    # oled-toggle — dual-monitor mode: disable/re-enable the G14's internal
    # OLED panel. Disabled monitors drop out of `hyprctl monitors -j`
    # entirely, so presence there is the toggle state.
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

      # Find keyboard backlight device (works across different systems)
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
