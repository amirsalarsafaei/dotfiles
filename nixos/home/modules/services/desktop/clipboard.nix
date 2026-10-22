{
  config,
  lib,
  pkgs,
  ...
}:
let
  hardening = import ../../systemd/lib.nix { inherit lib; };

  wayland = {
    BindReadOnlyPaths = [
      "-%t/wayland-0"
      "-%t/wayland-1"
    ];
    InaccessiblePaths = [ "/run/dbus" ];
    PrivateNetwork = true;
  };

  cliphistSandbox = lib.mkMerge [
    hardening.user
    wayland
    {
      Environment = [ "XDG_CACHE_HOME=%t" ];
      BindReadWritePaths = [ "%t/cliphist" ];
    }
  ];
in
{
  services.cliphist.enable = true;

  systemd.user.tmpfiles.rules = [
    "d %t/cliphist 0700 - - -"
    "R %h/.cache/cliphist - - - -"
  ];

  home.packages = [
    (pkgs.writeShellScriptBin "clipboard-menu" ''
      active=$(hyprctl activewindow -j 2>/dev/null | ${lib.getExe pkgs.jq} -r '.class // empty')
      cl() { XDG_CACHE_HOME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${lib.getExe pkgs.cliphist} "$@"; }
      sel=$(cl list \
        | ${lib.getExe pkgs.rofi} -dmenu -i -display-columns 2 -p "󰅍 Clipboard") || exit 0
      if [ -z "$sel" ]; then exit 0; fi
      printf '%s\n' "$sel" | cl decode | ${lib.getExe' pkgs.wl-clipboard "wl-copy"}
      sleep 0.12
      case "$active" in
        com.mitchellh.ghostty|*[Aa]lacritty*|kitty|*[Ff]oot*|org.wezfurlong.wezterm|*[Kk]itty*)
          ${lib.getExe pkgs.wtype} -M ctrl -M shift -k v -m shift -m ctrl ;;
        *)
          ${lib.getExe pkgs.wtype} -M ctrl -k v -m ctrl ;;
      esac
    '')
  ];

  systemd.user.services = {
    cliphist.Service = cliphistSandbox;
    cliphist-images = lib.mkIf config.services.cliphist.allowImages { Service = cliphistSandbox; };

    wl-clip-persist = {
      Unit = {
        Description = "Persist Wayland clipboard after the source app exits";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = lib.mkMerge [
        hardening.user
        wayland
        {
          ExecStart = "${lib.getExe pkgs.wl-clip-persist} --clipboard regular";
          Restart = "always";
          RestartSec = 2;
        }
      ];
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
