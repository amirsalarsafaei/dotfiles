{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.theme;

  base16Scheme = {
    scheme = "Slate";
    author = "Amirsalar";
    base00 = "0d1117"; # background - deep charcoal
    base01 = "161b22"; # lighter background
    base02 = "21262d"; # selection background
    base03 = "484f58"; # comments, invisibles
    base04 = "6e7681"; # dark foreground
    base05 = "c9d1d9"; # default foreground
    base06 = "d1d9e0"; # light foreground
    base07 = "e6edf3"; # lightest foreground
    base08 = "ff6b6b"; # red - errors, deletion
    base09 = "ff8c42"; # orange - integers
    base0A = "ffd93d"; # yellow - warnings
    base0B = "6bcf7f"; # green - strings, success
    base0C = "4fc3f7"; # cyan - support, regex
    base0D = "5b9cf6"; # blue - functions, methods
    base0E = "5b9cf6"; # blue (no purple) - keywords
    base0F = "8b949e"; # gray - deprecated, special
  };

  colors = lib.mapAttrs (_: value: "#${value}") (
    lib.filterAttrs (name: _: lib.hasPrefix "base" name) base16Scheme
  );

  resolved = {
    name = cfg.name;
    polarity = cfg.polarity;
    wallpaper = cfg.wallpaper;
    wallpaperDir = "${config.home.homeDirectory}/Pictures/wallpapers";
    rofiThemeName = "${cfg.name}-rofi";
    fonts = cfg.fonts;
    scheme = base16Scheme;
    colors = colors;
  };

  cssVariables = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "  --${name}: ${value};") resolved.colors
  );
in
{
  imports = [
    ./theme/opencode-compat.nix
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
      default = ./programs/desktop/hyprlock/hyprlock.png;
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
        default = "Inter";
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
    _module.args.themeLib = import ./theme/lib.nix { };

    stylix = {
      enable = true;
      autoEnable = true;
      image = cfg.wallpaper;
      polarity = cfg.polarity;
      base16Scheme = base16Scheme;

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

      opacity = {
        applications = 1.0;
        desktop = 1.0;
        popups = 0.95;
        terminal = 0.88;
      };

      targets = {
        hyprland.enable = false;
        hyprlock.enable = false;
        waybar.enable = false;
        rofi.enable = false;
        dunst.enable = false;
        neovim.enable = false;
        spicetify.enable = true;
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
