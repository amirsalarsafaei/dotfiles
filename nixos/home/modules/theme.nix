{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.theme;
  themeLib = import ./theme/lib.nix { };

  base16Scheme = {
    name = "Slate";
    scheme = "Slate";
    slug = "slate";
    author = "Amirsalar";
    base00 = "08090c";
    base01 = "17191e";
    base02 = "2b2f36";
    base03 = "586069";
    base04 = "8b949e";
    base05 = "c9d1d9";
    base06 = "d1d9e0";
    base07 = "e6edf3";
    base08 = "ff6b6b";
    base09 = "ff8c42";
    base0A = "ffd93d";
    base0B = "6bcf7f";
    base0C = "4fc3f7";
    base0D = "5b9cf6";
    base0E = "5b9cf6";
    base0F = "6e7681";
  };

  colors = lib.mapAttrs (_: value: "#${value}") (
    lib.filterAttrs (name: _: lib.hasPrefix "base" name) base16Scheme
  );

  surfaces = {
    ink = themeLib.mix colors.base00 "#000000" 45;
    raised = themeLib.mix colors.base00 colors.base01 55;
    line = themeLib.mix colors.base01 colors.base02 40;
  };

  accents = rec {
    primary = themeLib.mix colors.base05 colors.base02 35;
    secondary = themeLib.mix (themeLib.mix colors.base0D colors.base0C 50) colors.base02 30;
    heat = themeLib.mix colors.base09 colors.base02 25;
    warm = themeLib.mix colors.base0A colors.base09 45;
    border = themeLib.mix colors.base04 surfaces.line 50;
  };

  resolved = {
    inherit (cfg)
      name
      polarity
      wallpaper
      fonts
      ;
    wallpaperDir = "${config.home.homeDirectory}/Pictures/wallpapers";
    rofiThemeName = "${cfg.name}-rofi";
    scheme = base16Scheme;
    inherit colors surfaces accents;
  };

  iconTheme = {
    package = pkgs.papirus-icon-theme;
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };

  cssVariables = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "  --${name}: ${value};") resolved.colors
  );
in
{
  imports = [
    ./theme/qt.nix
  ];

  options.custom.theme = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "slate";
      description = "Canonical theme name shared across desktop modules.";
    };

    polarity = lib.mkOption {
      type = lib.types.enum [
        "dark"
        "light"
      ];
      default = "dark";
      description = "Preferred theme polarity for Stylix targets.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.path;
      default = ./theme/horizon.png;
      description = "Primary wallpaper shared by Stylix, Hyprlock, and wallpaper tools.";
    };

    fonts = {
      sans = lib.mkOption {
        type = lib.types.str;
        default = "Inter";
        description = "Sans font for desktop surfaces and headings.";
      };

      mono = lib.mkOption {
        type = lib.types.str;
        default = "JetBrainsMono Nerd Font";
        description = "Monospace font for terminals and launchers.";
      };

      display = lib.mkOption {
        type = lib.types.str;
        default = "Inter Display";
        description = "Display font for lockscreen and large UI elements.";
      };
    };

    resolved = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Resolved theme data exported to modules and external tools.";
    };
  };

  config = {
    _module.args.themeLib = themeLib;

    gtk.gtk4.theme = lib.mkForce null;

    gtk.gtk2.force = true;

    home.pointerCursor.enable = true;

    stylix = {
      enable = true;
      autoEnable = true;
      overlays.enable = false;
      image = cfg.wallpaper;
      inherit (cfg) polarity;
      inherit base16Scheme;

      fonts = {
        sansSerif = {
          package = pkgs.inter;
          name = "Inter";
        };
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font";
        };
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          applications = 12;
          desktop = 12;
          popups = 12;
          terminal = 13;
        };
      };

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      icons = iconTheme // {
        enable = true;
      };

      opacity = {
        applications = 1.0;
        desktop = 1.0;
        popups = 0.95;
        terminal = 1.0;
      };

      targets = {
        hyprland.enable = false;
        hyprlock.enable = false;
        waybar.enable = false;
        rofi.enable = false;
        dunst.enable = false;
        swaync.enable = false;
        neovim.enable = false;
        nixvim.enable = false;
        starship.enable = false;
        kde.enable = true;
      };
    };

    custom.theme.resolved = resolved;

    xdg.configFile."theme/current.json".text = builtins.toJSON resolved;
    xdg.configFile."theme/current.css".text = ''
      :root {
      ${cssVariables}
      }
    '';
  };
}
