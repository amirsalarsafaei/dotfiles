{
  config,
  lib,
  pkgs,
  currentHostname,
  ...
}:
let
  wine = pkgs.wineWow64Packages.staging;
  prefixDir = "${config.home.homeDirectory}/.local/share/wineprefixes/cisco-jabber";
  logDir = "${prefixDir}/drive_c/users/${config.home.username}/AppData/Local/Cisco/Unified Communications/Jabber/CSF/Logs";

  jabberWinetricksVerbs = [
    "corefonts"
    "gdiplus"
    "msxml3"
    "msxml6"
    "vcrun2013"
    "vcrun2015"
  ];

  wineEnvLines = ''
    export WINEARCH=win64
    export WINEPREFIX="${prefixDir}"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  '';

  ciscoJabberWine = pkgs.writeShellApplication {
    name = "cisco-jabber-wine";
    runtimeInputs = [ wine ];
    text = ''
      ${wineEnvLines}
      probe=$(wine cmd /c exit 2>&1 || true)
      if [[ $probe == *"version mismatch"* ]]; then
        echo "cisco-jabber-wine: a wineserver from another Wine build owns ${prefixDir}; stopping it" >&2
        wineserver -k || true
        wineserver -w || true
      fi
      exec wine "$@"
    '';
  };

  ciscoJabberBootstrap = pkgs.writeShellApplication {
    name = "cisco-jabber-bootstrap";
    runtimeInputs = [
      wine
      pkgs.winetricks
    ];
    text = ''
      ${wineEnvLines}
      mkdir -p "${prefixDir}"
      winetricks -q win10
      winetricks -q ${lib.concatStringsSep " " jabberWinetricksVerbs}
    '';
  };

  ciscoJabberInstall = pkgs.writeShellApplication {
    name = "cisco-jabber-install";
    runtimeInputs = [
      ciscoJabberWine
      ciscoJabberBootstrap
    ];
    text = ''
      if [[ $# -lt 1 ]]; then
        echo "Usage: cisco-jabber-install /path/to/CiscoJabberSetup.msi" >&2
        exit 1
      fi
      msi=$(readlink -f "$1")
      cisco-jabber-bootstrap
      cisco-jabber-wine msiexec /i "$msi"
    '';
  };

  msbcProfileFilter = pkgs.writeText "cisco-jabber-msbc-profile.jq" ''
    .[]
    | select((.name | startswith("bluez_card.")) and .active_profile != "off")
    | .name as $card
    | .active_profile as $active
    | [.profiles | to_entries[] | select(.value.available and (.value.description | contains("codec MSBC")))]
    | .[0] // empty
    | select(.key != $active)
    | "\($card) \(.key)"
  '';

  a2dpProfileFilter = pkgs.writeText "cisco-jabber-a2dp-profile.jq" ''
    .[]
    | select((.name | startswith("bluez_card.")) and (.active_profile // "" | startswith("headset-head-unit")))
    | .name as $card
    | [.profiles | to_entries[] | select(.value.available and (.key | startswith("a2dp-sink")))]
    | max_by(.value.priority) // empty
    | "\($card) \(.key)"
  '';

  ciscoJabberPinMsbc = pkgs.writeShellApplication {
    name = "cisco-jabber-pin-msbc";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.pulseaudio
      pkgs.wireplumber
    ];
    text = ''
      set_profiles() {
        pactl -f json list cards | jq -r -f "$1" | while read -r card profile; do
          pactl set-card-profile "$card" "$profile" || true
        done
      }

      pin() {
        set_profiles ${msbcProfileFilter}
      }

      restore() {
        set_profiles ${a2dpProfileFilter}
      }

      watcher=""
      cleanup() {
        if [[ -n $watcher ]]; then
          kill "$watcher" 2>/dev/null || true
        fi
        wpctl settings bluetooth.autoswitch-to-headset-profile true >/dev/null || true
        restore || true
      }
      trap cleanup EXIT
      trap 'exit 0' INT TERM HUP

      while true; do
        wpctl settings bluetooth.autoswitch-to-headset-profile false >/dev/null || true
        exec {events}< <(exec pactl subscribe)
        watcher=$!
        pin || true
        while read -r line <&"$events"; do
          if [[ $line == *" on card "* ]]; then
            pin || true
          fi
        done
        exec {events}<&-
        watcher=""
        sleep 2
      done
    '';
  };

  ciscoJabberLaunch = pkgs.writeShellApplication {
    name = "cisco-jabber";
    runtimeInputs = [
      ciscoJabberWine
      ciscoJabberPinMsbc
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = ''
      exe=$(find "${prefixDir}/drive_c" -iname 'CiscoJabber.exe' 2>/dev/null | head -n1)
      if [[ -z "$exe" ]]; then
        echo "Cisco Jabber isn't installed under ${prefixDir} yet." >&2
        echo "Grab CiscoJabberSetup.msi from the company's Webex portal, then run:" >&2
        echo "  cisco-jabber-install /path/to/CiscoJabberSetup.msi" >&2
        exit 1
      fi
      log="${logDir}/jabber.log"
      if [[ -f $log ]] && (($(stat -c %s "$log") > 5 * 1024 * 1024)); then
        mv "$log" "${logDir}/jabber-$(date +%Y%m%d-%H%M%S).log"
        find "${logDir}" -maxdepth 1 -name 'jabber-*.log' | sort -r | tail -n +11 | xargs -r -d '\n' rm -f --
      fi
      exec 9>"''${XDG_RUNTIME_DIR:?}/cisco-jabber-msbc.lock"
      if ! flock -n 9; then
        exec cisco-jabber-wine "$exe" "$@" 9>&-
      fi
      cisco-jabber-pin-msbc 9>&- &
      pin=$!
      trap 'kill "$pin" 2>/dev/null || true; wait "$pin" || true' EXIT
      cisco-jabber-wine "$exe" "$@" 9>&-
    '';
  };
in
lib.mkIf (currentHostname == "t14") {
  home.packages = [
    ciscoJabberWine
    ciscoJabberBootstrap
    ciscoJabberInstall
    ciscoJabberLaunch
  ];

  xdg.desktopEntries.cisco-jabber = {
    name = "Cisco Jabber";
    comment = "Cisco Jabber (Wine)";
    exec = "${ciscoJabberLaunch}/bin/cisco-jabber";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
    ];
  };
}
