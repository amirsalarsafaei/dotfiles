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
      "application/vnd.ms-excel"
      "application/vnd.oasis.opendocument.spreadsheet"
      "text/csv"
    ];
  };

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
  ];

  xdg = {
    desktopEntries.nvim-terminal = {
      name = "Neovim";
      genericName = "Text Editor";
      exec = "${lib.getExe pkgs.ghostty} -e ${lib.getExe config.programs.nixvim.build.package} %F";
      terminal = false;
      noDisplay = true;
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

    mimeApps = {
      enable = true;
      associations.added = byType;
      defaultApplications = byType;
    };
  };
}
