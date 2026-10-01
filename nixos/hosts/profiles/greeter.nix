{
  lib,
  pkgs,
  config,
  ...
}:
let
  filteredSessions = pkgs.runCommand "greeter-sessions" { } ''
    src=${config.services.displayManager.sessionData.desktops}
    for dir in wayland-sessions xsessions; do
      [ -d "$src/share/$dir" ] || continue
      mkdir -p "$out/share/$dir"
      for f in "$src/share/$dir"/*.desktop; do
        [ -e "$f" ] || continue
        [ "$(basename "$f")" = "hyprland.desktop" ] && continue
        ln -s "$f" "$out/share/$dir/"
      done
    done
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
