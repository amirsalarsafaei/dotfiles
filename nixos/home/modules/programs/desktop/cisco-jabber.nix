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
  '';

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
      wine
      ciscoJabberBootstrap
    ];
    text = ''
      if [[ $# -lt 1 ]]; then
        echo "Usage: cisco-jabber-install /path/to/CiscoJabberSetup.msi" >&2
        exit 1
      fi
      msi=$(readlink -f "$1")
      cisco-jabber-bootstrap
      ${wineEnvLines}
      wine msiexec /i "$msi"
    '';
  };

  ciscoJabberLaunch = pkgs.writeShellApplication {
    name = "cisco-jabber";
    runtimeInputs = [ wine ];
    text = ''
      ${wineEnvLines}
      exe=$(find "${prefixDir}/drive_c" -iname 'CiscoJabber.exe' 2>/dev/null | head -n1)
      if [[ -z "$exe" ]]; then
        echo "Cisco Jabber isn't installed under ${prefixDir} yet." >&2
        echo "Grab CiscoJabberSetup.msi from the company's Webex portal, then run:" >&2
        echo "  cisco-jabber-install /path/to/CiscoJabberSetup.msi" >&2
        exit 1
      fi
      exec wine "$exe" "$@"
    '';
  };
in
lib.mkIf (currentHostname == "t14") {
  home.packages = [
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
