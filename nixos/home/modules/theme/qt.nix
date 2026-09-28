{
  config,
  lib,
  pkgs,
  inputs,
  themeLib,
  ...
}:
let
  inherit (config.custom.theme.resolved) scheme colors;

  selection = themeLib.mix colors.base00 colors.base0D 40;

  bases = lib.filterAttrs (name: _: lib.hasPrefix "base" name) scheme;

  render = lib.replaceStrings (map (name: "{{${name}-hex}}") (lib.attrNames bases)) (
    lib.attrValues bases
  );

  stylixQt = "${inputs.stylix}/modules/qt";

  kvantumName = "${config.custom.theme.name}-kvantum";

  kvantumSvg = render (
    lib.replaceStrings
      [
        "opacity:0.2;fill:#{{base04-hex}}"
        "{{base04-hex}}"
      ]
      [
        "opacity:0.16;fill:#{{base0D-hex}}"
        (themeLib.stripHash selection)
      ]
      (builtins.readFile "${stylixQt}/kvantum.svg.mustache")
  );

  kvantumConfig = render (builtins.readFile "${stylixQt}/kvconfig.mustache");

  kvantumTheme = pkgs.runCommandLocal kvantumName { } ''
    directory="$out/share/Kvantum/${kvantumName}"
    mkdir --parents "$directory"
    cp ${pkgs.writeText "${kvantumName}.kvconfig" kvantumConfig} "$directory/${kvantumName}.kvconfig"
    cp ${pkgs.writeText "${kvantumName}.svg" kvantumSvg} "$directory/${kvantumName}.svg"
  '';

  schemeSlug = lib.concatStrings (lib.filter lib.isString (builtins.split "[^a-zA-Z]" scheme.scheme));

  rgb = color: lib.replaceStrings [ " " ] [ "" ] (themeLib.hexToRgb color);

  foreground = {
    ForegroundNormal = rgb colors.base05;
    ForegroundActive = rgb colors.base07;
    ForegroundInactive = rgb colors.base04;
    ForegroundLink = rgb colors.base0D;
    ForegroundVisited = rgb colors.base0E;
    ForegroundNegative = rgb colors.base08;
    ForegroundNeutral = rgb colors.base0A;
    ForegroundPositive = rgb colors.base0B;
    DecorationFocus = rgb colors.base0D;
    DecorationHover = rgb colors.base0D;
  };

  colorGroup =
    normal: alternate: overrides:
    foreground
    // {
      BackgroundNormal = rgb normal;
      BackgroundAlternate = rgb alternate;
    }
    // overrides;

  onSelection = lib.genAttrs [
    "ForegroundNormal"
    "ForegroundActive"
    "ForegroundInactive"
    "ForegroundLink"
    "ForegroundVisited"
  ] (_: rgb colors.base00);

  colorScheme = {
    General = {
      ColorScheme = schemeSlug;
      Name = scheme.scheme;
    };

    "ColorEffects:Disabled" = {
      ColorEffect = 0;
      ColorAmount = 0;
      ContrastEffect = 1;
      ContrastAmount = 0.5;
      IntensityEffect = 0;
      IntensityAmount = 0;
    };

    "ColorEffects:Inactive" = {
      Enable = false;
      ChangeSelectionColor = false;
    };

    "Colors:View" = colorGroup colors.base00 colors.base01 { };
    "Colors:Window" = colorGroup colors.base01 colors.base00 { };
    "Colors:Header" = colorGroup colors.base01 colors.base00 { };
    "Colors:Button" = colorGroup colors.base02 colors.base03 { };
    "Colors:Tooltip" = colorGroup colors.base01 colors.base00 { };
    "Colors:Complementary" = colorGroup colors.base00 colors.base01 { };
    "Colors:Selection" = colorGroup colors.base0D selection onSelection;

    WM = {
      activeBackground = rgb colors.base01;
      activeForeground = rgb colors.base05;
      activeBlend = rgb colors.base0D;
      inactiveBackground = rgb colors.base00;
      inactiveForeground = rgb colors.base04;
      inactiveBlend = rgb colors.base03;
    };
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.qt.style.name == "kvantum") {
      qt.kvantum = {
        themes = [ kvantumTheme ];
        settings.General.theme = lib.mkForce kvantumName;
      };
    })

    (lib.mkIf config.stylix.targets.kde.enable {
      xdg.dataFile."color-schemes/${schemeSlug}.colors".text = lib.generators.toINI { } colorScheme;
    })
  ];
}
