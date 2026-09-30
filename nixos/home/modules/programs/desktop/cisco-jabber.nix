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

  ciscoJabberLaunch = pkgs.writeShellApplication {
    name = "cisco-jabber";
    runtimeInputs = [
      ciscoJabberWine
      pkgs.coreutils
      pkgs.findutils
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
      exec cisco-jabber-wine "$exe" "$@"
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
