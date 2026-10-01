{ lib, pkgs, ... }:

let
  chrome = "google-chrome-stable";

  chromiumDomains = [
    "openai.com"
    "chatgpt.com"
    "oaistatic.com"
    "oaiusercontent.com"
    "sora.com"
    "anthropic.com"
    "claude.ai"
    "claude.com"
  ];

  chromiumDomainPattern = lib.concatMapStringsSep "|" (d: "${d}|*.${d}") chromiumDomains;

  webRouter = pkgs.writeShellApplication {
    name = "web-router";
    runtimeInputs = [
      pkgs.chromium
      pkgs.google-chrome
    ];
    text = ''
      shopt -s extglob

      url="''${1:-}"
      host="''${url#*://}"
      host="''${host%%[/?#]*}"
      host="''${host%%:*}"

      case "$host" in
        @(${chromiumDomainPattern}))
          exec chromium "$@"
          ;;
        *)
          exec ${chrome} "$@"
          ;;
      esac
    '';
  };

  webTypes = [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ];
in
{
  home.packages = [ webRouter ];

  xdg.desktopEntries.web-router = {
    name = "Web Router";
    comment = "Routes AI-vendor domains to Chromium, everything else to Chrome";
    exec = "${webRouter}/bin/web-router %u";
    terminal = false;
    noDisplay = true;
    mimeType = webTypes;
    categories = [
      "Network"
      "WebBrowser"
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.genAttrs webTypes (_: "web-router.desktop");
  };

  home.sessionVariables.BROWSER = "web-router";
}
