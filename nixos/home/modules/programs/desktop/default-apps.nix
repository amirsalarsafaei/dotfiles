{
  config,
  lib,
  pkgs,
  ...
}:

let
  textTypes = [
    "text/plain"
    "text/markdown"
    "text/x-log"
    "text/x-csrc"
    "text/x-chdr"
    "text/x-c++src"
    "text/x-c++hdr"
    "text/x-python"
    "text/x-go"
    "text/x-rust"
    "text/x-lua"
    "text/x-nix"
    "text/x-makefile"
    "text/x-tex"
    "text/x-diff"
    "text/x-patch"
    "application/json"
    "application/x-yaml"
    "application/yaml"
    "application/toml"
    "application/xml"
    "application/x-shellscript"
    "application/javascript"
    "application/x-desktop"
  ];

  handlers = {
    "nvim-terminal.desktop" = textTypes;

    "thunar.desktop" = [ "inode/directory" ];

    "org.kde.gwenview.desktop" = [
      "image/png"
      "image/jpeg"
      "image/gif"
      "image/webp"
      "image/bmp"
      "image/tiff"
      "image/avif"
      "image/heif"
      "image/jxl"
      "image/svg+xml"
      "image/x-icon"
    ];

    "org.kde.okular.desktop" = [
      "application/pdf"
      "application/epub+zip"
      "image/vnd.djvu"
    ];

    "abiword.desktop" = [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/msword"
      "application/vnd.oasis.opendocument.text"
      "application/rtf"
      "text/rtf"
    ];

    "org.gnumeric.gnumeric.desktop" = [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.ms-excel"
      "application/vnd.oasis.opendocument.spreadsheet"
      "text/csv"
      "text/tab-separated-values"
    ];

    "vlc.desktop" = [
      "video/mp4"
      "video/x-matroska"
      "video/webm"
      "video/quicktime"
      "video/x-msvideo"
      "video/mpeg"
      "video/mp2t"
      "video/ogg"
      "video/x-flv"
      "video/3gpp"
      "video/x-ms-wmv"
      "audio/mpeg"
      "audio/mp4"
      "audio/x-m4a"
      "audio/aac"
      "audio/flac"
      "audio/x-flac"
      "audio/ogg"
      "audio/x-vorbis+ogg"
      "audio/opus"
      "audio/x-opus+ogg"
      "audio/wav"
      "audio/x-wav"
      "audio/webm"
      "audio/x-matroska"
    ];

    "org.gnome.FileRoller.desktop" = [
      "application/zip"
      "application/x-zip-compressed"
      "application/x-7z-compressed"
      "application/vnd.rar"
      "application/x-rar"
      "application/x-rar-compressed"
      "application/x-tar"
      "application/x-compressed-tar"
      "application/x-bzip-compressed-tar"
      "application/x-xz-compressed-tar"
      "application/x-zstd-compressed-tar"
      "application/x-lzma-compressed-tar"
      "application/x-lz4-compressed-tar"
      "application/gzip"
      "application/x-gzip"
      "application/x-bzip"
      "application/bzip2"
      "application/x-xz"
      "application/zstd"
      "application/x-lzma"
      "application/x-lz4"
      "application/x-cpio"
    ];
  };

  hiddenEntries = [
    "thunar-settings"
    "thunar-bulk-rename"
    "rofi"
    "rofi-theme-selector"
    "uuctl"
    "xterm"
    "vim"
    "gvim"
    "nvim"
    "htop"
    "qt5ct"
    "qt6ct"
    "kvantummanager"
  ];

  byType = lib.foldlAttrs (
    acc: app: types:
    acc // lib.genAttrs types (_: [ app ])
  ) { } handlers;
in
{
  home.packages = [
    pkgs.kdePackages.gwenview
    pkgs.kdePackages.okular
    pkgs.abiword
    pkgs.gnumeric
    pkgs.file-roller
  ];

  xdg = {
    desktopEntries.nvim-terminal = {
      name = "Neovim";
      genericName = "Text Editor";
      exec = "${lib.getExe pkgs.ghostty} -e ${lib.getExe config.programs.nixvim.build.package} %F";
      terminal = false;
      mimeType = textTypes;
      categories = [
        "Utility"
        "TextEditor"
      ];
    };

    configFile."Thunar/uca.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <actions>
        <action>
          <icon>utilities-terminal</icon>
          <name>Open Terminal Here</name>
          <unique-id>open-terminal-here</unique-id>
          <command>${lib.getExe pkgs.ghostty} --working-directory=%f</command>
          <description>Open Ghostty in this folder</description>
          <patterns>*</patterns>
          <startup-notify/>
          <directories/>
        </action>
      </actions>
    '';

    dataFile = lib.listToAttrs (
      map (
        id:
        lib.nameValuePair "applications/${id}.desktop" {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=${id}
            Hidden=true
          '';
        }
      ) hiddenEntries
    );

    mimeApps = {
      enable = true;
      associations.added = byType;
      defaultApplications = byType;
    };
  };
}
