{ lib, pkgs, ... }:
{
  services.cliphist.enable = true;

  home.packages = [
    (pkgs.writeShellScriptBin "clipboard-menu" ''
      active=$(hyprctl activewindow -j 2>/dev/null | ${lib.getExe pkgs.jq} -r '.class // empty')
      sel=$(${lib.getExe pkgs.cliphist} list \
        | ${lib.getExe pkgs.rofi} -dmenu -i -display-columns 2 -p "󰅍 Clipboard") || exit 0
      if [ -z "$sel" ]; then exit 0; fi
      printf '%s\n' "$sel" | ${lib.getExe pkgs.cliphist} decode | ${lib.getExe' pkgs.wl-clipboard "wl-copy"}
      sleep 0.12
      case "$active" in
        com.mitchellh.ghostty|*[Aa]lacritty*|kitty|*[Ff]oot*|org.wezfurlong.wezterm|*[Kk]itty*)
          ${lib.getExe pkgs.wtype} -M ctrl -M shift -k v -m shift -m ctrl ;;
        *)
          ${lib.getExe pkgs.wtype} -M ctrl -k v -m ctrl ;;
      esac
    '')
  ];

  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Persist Wayland clipboard after the source app exits";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.wl-clip-persist} --clipboard regular";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
