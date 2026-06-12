{ pkgs, ... }:
{
  # cliphist is the de-facto Wayland clipboard-history daemon. home-manager's
  # services.cliphist wires up `wl-paste --watch cliphist store` for both text
  # and images, bound to graphical-session.target — nothing hand-rolled to
  # babysit. The picker is plain rofi (Super+V, see hyprland.nix), so history
  # reuses the already-themed launcher instead of a separate TUI + theme file.
  services.cliphist.enable = true;

  # Super+V glue: pick an entry in rofi (inherits the themed .rasi + icon
  # prompt), copy it, then fake the paste chord into whatever window had focus
  # before rofi grabbed it. Lives here rather than inline in the Hyprland bind
  # because Hyprland's own $-variable parser would mangle the $(…)/$sel shell
  # syntax.
  #
  # The paste chord isn't universal on Wayland: terminals (ghostty, etc.) use
  # Ctrl+Shift+V, GUI apps use Ctrl+V. So we capture the focused window's class
  # *before* rofi steals focus and pick the chord to match. (Inside a terminal
  # nvim this still routes through the terminal's paste, which is what you want
  # for normal/insert paste; the entry is always on the clipboard regardless.)
  home.packages = [
    (pkgs.writeShellScriptBin "clipboard-menu" ''
      # window that has focus *now*, before rofi grabs it
      active=$(hyprctl activewindow -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.class // empty')
      sel=$(${pkgs.cliphist}/bin/cliphist list \
        | ${pkgs.rofi}/bin/rofi -dmenu -i -display-columns 2 -p "󰅍 Clipboard") || exit 0
      if [ -z "$sel" ]; then exit 0; fi
      printf '%s\n' "$sel" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
      # let focus snap back to the pre-rofi window before injecting the paste
      sleep 0.12
      case "$active" in
        com.mitchellh.ghostty|*[Aa]lacritty*|kitty|*[Ff]oot*|org.wezfurlong.wezterm|*[Kk]itty*)
          ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v -m shift -m ctrl ;;
        *)
          ${pkgs.wtype}/bin/wtype -M ctrl -k v -m ctrl ;;
      esac
    '')
  ];

  # Wayland hands clipboard ownership to the *source* app: copy in a browser or
  # GUI app, then close/background it, and the selection goes empty — the
  # classic "clipboard only works in the terminal" symptom. wl-clip-persist
  # grabs ownership and re-serves the data so it survives the source closing,
  # which also keeps cliphist's history populated from GUI apps.
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Persist Wayland clipboard after the source app exits";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      # `regular` = the Ctrl+C/Ctrl+V clipboard only; leaving the primary
      # (middle-click) selection alone avoids surprises with text selection
      # and the feedback loops that `both` can cause with a history daemon.
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
