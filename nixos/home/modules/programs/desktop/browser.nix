{ lib, pkgs, ... }:

let
  # Binary shipped by pkgs.google-chrome (home/modules/packages/platform.nix) —
  # the fallback target for every site not in chromiumDomains below.
  chrome = "google-chrome-stable";

  # AI-vendor sites that should open in chromium (its own profile/extensions,
  # e.g. the Cloaq/WebRTC-blocking setup in modules/work.nix) instead of the
  # default Chrome profile. Suffix-matched below, so subdomains (chat.openai.com,
  # docs.anthropic.com, ...) are covered without listing them individually.
  chromiumDomains = [
    "openai.com"
    "chatgpt.com"
    "oaistatic.com" # OpenAI static asset CDN
    "oaiusercontent.com" # OpenAI user-content/upload CDN
    "sora.com"
    "anthropic.com"
    "claude.ai"
    "claude.com" # redirects to claude.ai, but route it directly too
  ];

  chromiumDomainPattern = lib.concatMapStringsSep "|" (d: "${d}|*.${d}") chromiumDomains;

  # Dispatches by hostname: chromiumDomains go to chromium, everything else
  # falls through to Chrome — i.e. this replaces Chrome as the system default
  # while keeping Chrome as the behavior for every site not in the list.
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

      # @(...) is an extglob group: "|" alternation inside it is honored even
      # though the pattern comes from a variable — a plain unquoted case
      # pattern would only split on "|" that the shell parser sees literally,
      # not "|" bytes sitting inside an expanded variable.
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

  # Everything that should open a browser window. PDFs are deliberately left
  # alone — Chrome claims application/pdf too, and that is a separate decision.
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

  # Note: this makes ~/.config/mimeapps.list a read-only store symlink, so
  # Chrome's own "make default" button can no longer write to it. That is the
  # point — the default lives here instead of drifting at runtime.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.genAttrs webTypes (_: "web-router.desktop");
  };

  # For terminal programs that shell out to $BROWSER rather than xdg-open —
  # routed the same way as clicked links.
  home.sessionVariables.BROWSER = "web-router";
}
