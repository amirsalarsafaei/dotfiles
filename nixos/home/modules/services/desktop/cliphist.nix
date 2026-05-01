{ pkgs, config, ... }:
let
  rofiThemeName = config.custom.theme.resolved.rofiThemeName;
in
{
  services.cliphist = {
    enable = true;
    systemdTargets = [
      "hyprland-session.target"
      "graphical-session.target"
    ];
  };

  home.packages = [
    (pkgs.writeShellScriptBin "rofi-cliphist" ''
            #!/usr/bin/env bash
            set -euo pipefail

            theme="${rofiThemeName}"

            pick_entry() {
              local prompt="$1"
              cliphist list | rofi -dmenu -i -no-custom -p "$prompt" -theme "$theme" || true
            }

            action="''${1:-paste}"
            case "$action" in
              paste)
                selected_entry="$(pick_entry "Paste from Clipboard")"
                [ -n "$selected_entry" ] || exit 0
                printf '%s' "$selected_entry" | cliphist decode | wl-copy

                (
                  sleep 0.15
                  if wtype -M ctrl -k v -m ctrl >/dev/null 2>&1; then
                    notify-send "Clipboard" "Pasted selection"
                  else
                    notify-send "Clipboard" "Copied selection (press Ctrl+V)"
                  fi
                ) &
                ;;
              copy)
                selected_entry="$(pick_entry "Copy from Clipboard")"
                [ -n "$selected_entry" ] || exit 0
                printf '%s' "$selected_entry" | cliphist decode | wl-copy
                notify-send "Clipboard" "Copied to clipboard"
                ;;
              delete)
                selected_entry="$(pick_entry "Delete from Clipboard")"
                [ -n "$selected_entry" ] || exit 0
                printf '%s' "$selected_entry" | cliphist delete
                notify-send "Clipboard" "Deleted entry"
                ;;
              clear)
                choice="$(printf "No
      Yes" | rofi -dmenu -p "Clear clipboard history?" -theme "$theme" || true)"
                [ "$choice" = "Yes" ] || exit 0
                cliphist wipe
                notify-send "Clipboard" "Clipboard history cleared"
                ;;
              *)
                echo "Usage: rofi-cliphist [paste|copy|delete|clear]" >&2
                exit 1
                ;;
            esac
    '')
  ];
}
