{ pkgs, ... }:
{
  services.cliphist = {
    enable = true;
    # Automatically store clipboard history
    systemdTargets = [ "graphical-session.target" ];
  };

  # Add helper scripts for cliphist integration with rofi
  home.packages = [
    (pkgs.writeShellScriptBin "rofi-cliphist" ''
      #!/usr/bin/env bash
      set -euo pipefail

      selected_entry="$(
        cliphist list | rofi -dmenu -i -p "Paste from Clipboard" -theme catppuccin-mocha
      )"
      [ -n "$selected_entry" ] || exit 0

      printf '%s' "$selected_entry" | cliphist decode | wl-copy
      (
        sleep 0.15
        wtype -M ctrl -k v -m ctrl
      ) >/dev/null 2>&1 &
      notify-send "Clipboard" "Pasted selection"
    '')
    (pkgs.writeShellScriptBin "rofi-cliphist-paste" ''
      # Compatibility wrapper
      exec rofi-cliphist
    '')
    (pkgs.writeShellScriptBin "rofi-cliphist-copy" ''
      #!/usr/bin/env bash
      set -euo pipefail

      selected_entry="$(
        cliphist list | rofi -dmenu -i -p "Copy from Clipboard" -theme catppuccin-mocha
      )"
      [ -n "$selected_entry" ] || exit 0
      printf '%s' "$selected_entry" | cliphist decode | wl-copy
      notify-send "Clipboard" "Copied to clipboard"
    '')
    (pkgs.writeShellScriptBin "rofi-cliphist-delete" ''
      #!/usr/bin/env bash
      set -euo pipefail

      selected_entry="$(
        cliphist list | rofi -dmenu -i -p "Delete from Clipboard" -theme catppuccin-mocha
      )"
      [ -n "$selected_entry" ] || exit 0
      printf '%s' "$selected_entry" | cliphist delete
      notify-send "Clipboard" "Deleted entry"
    '')
    (pkgs.writeShellScriptBin "cliphist-clear" ''
      choice="$(printf "No\nYes" | rofi -dmenu -p "Clear clipboard history?" -theme catppuccin-mocha)"
      if [ "$choice" = "Yes" ]; then
        cliphist wipe
        notify-send "Clipboard" "Clipboard history cleared"
      fi
    '')
  ];
}
