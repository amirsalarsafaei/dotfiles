{ pkgs, ... }:
{
  services.cliphist = {
    enable = true;
    # Automatically store clipboard history
    systemdTargets = [ "hyprland-session.target" ];
  };

  # Add helper scripts for cliphist integration with rofi
  home.packages = [
    (pkgs.writeShellScriptBin "rofi-cliphist-paste" ''
      cliphist list | rofi -dmenu -p "Clipboard" -theme catppuccin-mocha -display-columns 2 | cliphist decode | wl-copy
    '')
    (pkgs.writeShellScriptBin "rofi-cliphist-delete" ''
      cliphist list | rofi -dmenu -p "Delete from Clipboard" -theme catppuccin-mocha -display-columns 2 | cliphist delete
    '')
    (pkgs.writeShellScriptBin "cliphist-clear" ''
      cliphist wipe
      notify-send "Clipboard History" "Cleared clipboard history"
    '')
  ];
}
