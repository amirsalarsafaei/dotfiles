# Minimal terminal-style login manager: greetd running tuigreet on the TTY.
# Replaces SDDM/Plasma's graphical greeter with a fast text greeter that lists
# every registered session (Hyprland, Plasma, ...) so any of them can be picked.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  # All registered session desktop files (wayland-sessions + xsessions), so
  # tuigreet's session menu mirrors whatever desktops/WMs are installed.
  #
  # Hyprland (with programs.hyprland.withUWSM = true) ships TWO entries:
  #   hyprland.desktop       -> start-hyprland  (launches Hyprland directly)
  #   hyprland-uwsm.desktop  -> uwsm start ...  (proper systemd user session)
  # withUWSM only *adds* the uwsm entry; it doesn't remove the bare one, so with
  # --remember-session tuigreet can land on the non-uwsm session. Filter the
  # plain hyprland.desktop out so the only Hyprland option is uwsm-managed.
  # (Plasma brings its own session manager, so it's left untouched.)
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

  # Named colors map onto the TTY palette; blue/cyan accent matches the
  # Slate desktop theme without needing graphical assets.
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
    # tuigreet is a TUI, so let the greetd module wire up its systemd service
    # (display-manager.service) with the TTY handling that keeps kernel/systemd
    # boot logs from spamming over the greeter: TTYReset/TTYVHangup/TTYVTDisallocate
    # on /dev/tty1, StandardError to the journal. This is the proper fix for the
    # log-spam-on-greeter problem (vs. just quieting the console).
    useTextGreeter = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        tuigreet
        "--time --time-format '%a %d %b  %H:%M'"
        "--remember --remember-session" # recall last user + session
        "--user-menu" # pick from a list instead of typing the username
        "--asterisks" # mask the password with *
        "--greeting 'Welcome back'"
        "--sessions ${sessions}"
        "--theme '${theme}'"
      ];
      user = "greeter";
    };
  };

  # The G14 panel is 2880x1800; the default 8x16 console font renders tuigreet's
  # text microscopically and the login box looks lost. A large Terminus font
  # (16x32) makes the TUI fill the screen with big, crisp text. earlySetup loads
  # it in the initrd so the greeter is already scaled by the time it appears.
  console = {
    earlySetup = true;
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
  };

  # greetd's tuigreet runs on VT1, which is also where the kernel and systemd
  # print boot messages by default, so the log spam paints over the greeter.
  # Plasma/SDDM used to hide this. Plymouth holds a clean splash until greetd is
  # ready (seamless handoff), and the quiet kernel params stop the console noise
  # from leaking onto the greeter's VT.
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

  # Auto-unlock the GNOME keyring on login, same as the old SDDM integration.
  security.pam.services.greetd.enableGnomeKeyring = true;
}
