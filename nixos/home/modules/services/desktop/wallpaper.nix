{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = config.custom.theme.resolved;

  variants =
    pkgs.runCommand "wallpaper-variants"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        magick ${theme.wallpaper} -strip $out/idle.png
        magick ${theme.wallpaper} -strip \
          -resize 25% -blur 0x6 -resize 400% \
          -modulate 72,85 \
          -fill '${theme.surfaces.ink}' -colorize 22% \
          $out/busy.png
      '';

  wallpaperReact = pkgs.writeShellApplication {
    name = "wallpaper-react";
    runtimeInputs = [
      config.services.awww.package
      pkgs.hyprland
      pkgs.jq
      pkgs.socat
      pkgs.coreutils
      pkgs.systemd
      pkgs.libnotify
    ];
    text = ''
      idle=${variants}/idle.png
      busy=${variants}/busy.png
      off="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-react/off"
      declare -A shown=()

      if [ "''${1:-}" = toggle ]; then
        mkdir -p "$(dirname "$off")"
        if [ -e "$off" ]; then
          rm -f "$off"
          notify-send -t 2000 "Wallpaper" "Blur behind windows: on"
        else
          touch "$off"
          notify-send -t 2000 "Wallpaper" "Blur behind windows: off"
        fi
        systemctl --user restart wallpaper-react.service
        exit 0
      fi

      until awww query >/dev/null 2>&1; do sleep 0.5; done

      update() {
        local monitors workspaces name state image filter
        monitors=$(hyprctl monitors -j) || return 0
        workspaces=$(hyprctl workspaces -j) || return 0
        while read -r name state; do
          [ -n "$name" ] || continue
          [ -e "$off" ] && state=idle
          [ "''${shown[$name]:-}" = "$state" ] && continue
          image=$idle
          filter=Nearest
          if [ "$state" = busy ]; then
            image=$busy
            filter=Lanczos3
          fi
          if awww img -o "$name" "$image" \
            --filter "$filter" \
            --transition-type fade \
            --transition-duration 0.8 \
            --transition-fps 60; then
            shown[$name]=$state
          fi
        done < <(
          jq -r --argjson ws "$workspaces" '
            .[]
            | . as $m
            | ([$ws[] | select(.id == $m.activeWorkspace.id) | .windows][0] // 0) as $count
            | "\($m.name) \(if $count > 0 or (($m.specialWorkspace.id // 0) != 0) then "busy" else "idle" end)"
          ' <<<"$monitors"
        )
      }

      update
      socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - \
        | while IFS= read -r event; do
            case "$event" in
              monitoradded\>\>*|monitorremoved\>\>*|configreloaded\>\>*)
                shown=()
                update
                ;;
              workspace\>\>*|focusedmon\>\>*|openwindow\>\>*|closewindow\>\>*|movewindow\>\>*|activespecial\>\>*)
                update
                ;;
            esac
          done
    '';
  };
in
{
  services.awww.enable = true;

  home.packages = [ wallpaperReact ];

  custom.keys.commands.wallpaperBlurToggle = "${lib.getExe wallpaperReact} toggle";

  systemd.user.services.wallpaper-react = {
    Unit = {
      Description = "Blur and darken the wallpaper while windows cover it";
      After = [
        "awww.service"
        config.wayland.systemd.target
      ];
      Requires = [ "awww.service" ];
      PartOf = [ config.wayland.systemd.target ];
      ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
    };
    Service = {
      ExecStart = lib.getExe wallpaperReact;
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
