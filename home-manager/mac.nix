{ pkgs, ... }: {
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/x-extension-htm" = [ "chromium.desktop" ];
      "application/x-extension-html" = [ "chromium.desktop" ];
      "application/x-extension-shtml" = [ "chromium.desktop" ];
      "application/x-extension-xht" = [ "chromium.desktop" ];
      "application/x-extension-xhtml" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "video/quicktime" = [ "vlc-2.desktop" ];
      "video/x-matroska" = [ "vlc-4.desktop" "vlc-3.desktop" ];
      "x-scheme-handler/chrome" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };

    defaultApplications = {
      "application/x-extension-htm" = "chromium.desktop";
      "application/x-extension-html" = "chromium.desktop";
      "application/x-extension-shtml" = "chromium.desktop";
      "application/x-extension-xht" = "chromium.desktop";
      "application/x-extension-xhtml" = "chromium.desktop";
      "application/xhtml+xml" = "chromium.desktop";
      "text/html" = "chromium.desktop";
      "video/quicktime" = "vlc-2.desktop";
      "video/x-matroska" = "vlc-4.desktop";
      "x-scheme-handler/chrome" = "chromium.desktop";
      "x-scheme-handler/http" = "chromium.desktop";
      "x-scheme-handler/https" = "chromium.desktop";
      "x-scheme-handler/postman" = "chromium.desktop";
    };
  };
}
