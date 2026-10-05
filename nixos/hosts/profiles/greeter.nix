{
  lib,
  pkgs,
  config,
  ...
}:
let
  scenes = import ../../home/modules/programs/desktop/quickshell/scenes.nix;

  sceneSession = pkgs.writeShellApplication {
    name = "hyprland-scene";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      scene=$1
      shift
      state="''${XDG_STATE_HOME:-$HOME/.local/state}"
      prefs="$state/${scenes.prefsFile}"
      current='{}'
      if [ -s "$prefs" ] && jq -e 'type == "object"' "$prefs" >/dev/null 2>&1; then
        current=$(cat "$prefs")
      fi
      if mkdir -p "$state" && jq --arg scene "$scene" '.scene = $scene' <<<"$current" >"$prefs.tmp"; then
        mv "$prefs.tmp" "$prefs" || true
      fi
      exec "$@"
    '';
  };

  sceneEntries = lib.concatMapStrings (scene: ''
    {
      echo "[Desktop Entry]"
      echo "Name=Hyprland · ${scene}"
      echo "Comment=Hyprland with the ${scene} desktop scene"
      echo "Exec=${lib.getExe sceneSession} ${scene} $uwsm"
      echo "DesktopNames=Hyprland"
      echo "Type=Application"
    } >"$out/share/wayland-sessions/hyprland-${scene}.desktop"
  '') scenes.names;

  filteredSessions = pkgs.runCommand "greeter-sessions" { } ''
    src=${config.services.displayManager.sessionData.desktops}
    uwsm=""
    if [ -e "$src/share/wayland-sessions/hyprland-uwsm.desktop" ]; then
      uwsm=$(sed -n 's/^Exec=//p' "$src/share/wayland-sessions/hyprland-uwsm.desktop" | head -n 1)
    fi
    for dir in wayland-sessions xsessions; do
      [ -d "$src/share/$dir" ] || continue
      mkdir -p "$out/share/$dir"
      for f in "$src/share/$dir"/*.desktop; do
        [ -e "$f" ] || continue
        case "$(basename "$f")" in
          hyprland.desktop) continue ;;
          hyprland-uwsm.desktop) [ -n "$uwsm" ] && continue ;;
        esac
        ln -s "$f" "$out/share/$dir/"
      done
    done
    if [ -n "$uwsm" ]; then
      mkdir -p "$out/share/wayland-sessions"
      ${sceneEntries}
    fi
  '';
  sessions = "${filteredSessions}/share/wayland-sessions:${filteredSessions}/share/xsessions";

  theme = lib.concatStringsSep ";" [
    "border=blue"
    "text=white"
    "prompt=cyan"
    "time=cyan"
    "action=white"
    "button=blue"
    "container=black"
    "input=white"
  ];

  tuigreet = lib.getExe pkgs.tuigreet;
in
{
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        tuigreet
        "--time --time-format '%a %d %b  %H:%M'"
        "--remember --remember-session"
        "--user-menu"
        "--asterisks"
        "--greeting 'Welcome back'"
        "--sessions ${sessions}"
        "--theme '${theme}'"
      ];
      user = "greeter";
    };
  };

  console = {
    earlySetup = true;
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
  };

  boot = {
    plymouth.enable = true;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.systemd.show_status=auto"
      "vt.global_cursor_default=0"
    ];
  };

  security.pam.services.greetd.enableGnomeKeyring = true;
}
