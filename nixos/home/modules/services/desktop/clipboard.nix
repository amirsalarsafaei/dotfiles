{ pkgs, ... }:
{
  services.cliphist.enable = true;

  home.packages = [
    (pkgs.writeShellScriptBin "clipboard-menu" ''
      active=$(hyprctl activewindow -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.class // empty')
      sel=$(${pkgs.cliphist}/bin/cliphist list \
        | ${pkgs.rofi}/bin/rofi -dmenu -i -display-columns 2 -p "󰅍 Clipboard") || exit 0
      if [ -z "$sel" ]; then exit 0; fi
      printf '%s\n' "$sel" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
      sleep 0.12
      case "$active" in
        com.mitchellh.ghostty|*[Aa]lacritty*|kitty|*[Ff]oot*|org.wezfurlong.wezterm|*[Kk]itty*)
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v -m shift -m ctrl ;;
        *)
          ${pkgs.wtype}/bin/wtype -M ctrl -k v -m ctrl ;;
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
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
