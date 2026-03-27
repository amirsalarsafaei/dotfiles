{ lib, config, ... }:

let
  # ── Base palette (cool, masculine, low-fatigue) ──────────────────────────
  mocha = {
    # Base layers
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";

    # Surface layers
    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";

    # Overlay layers
    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";

    # Text layers
    subtext0 = "#a6adc8";
    subtext1 = "#bac2de";
    text = "#cdd6f4";

    # Accent colours (no pink/purple bias)
    lavender = "#9bbcff";
    blue = "#7aa2f7";
    sapphire = "#5fb3d9";
    sky = "#76cce0";
    teal = "#6fbdb3";
    green = "#8fbf7f";
    yellow = "#d6b57a";
    peach = "#d49a6a";
    maroon = "#bf616a";
    red = "#d16d6d";
    mauve = "#5d8fd8";
    pink = "#76b3d6";
    flamingo = "#8ea4bf";
    rosewater = "#a7b4c9";
  };

  # ── Semantic aliases (modern glass layer) ─────────────────────────────────
  semantic = {
    bg = "#10151d"; # primary background
    bgDark = "#0c1219"; # darker panels / urgency-low
    bgDarker = "#080d13"; # deepest chrome (tooltips, overlays)
    surface = "#212c3a"; # raised surfaces, borders, separators
    muted = "#79849a"; # inactive / disabled text
    subtle = "#95a3ba"; # secondary text
    fg = "#c5d0de"; # primary text
    fgBright = "#ecf1f8"; # maximum contrast (clock, headings)
    accent = "#78a6ff"; # primary accent (borders, highlights, progress)
    accentAlt = "#5f9fcf"; # secondary accent
    accentSoft = "#869db6"; # tertiary accent
    urgent = "#d06a6a"; # errors, critical urgency
    warning = "#d1b178"; # warnings
    ok = "#89b97c"; # success / ok states
    info = "#73a0f4"; # informational
    glass = "#141e2c"; # translucent card base
    glassStrong = "#0e1724"; # stronger translucent base
    glassBorder = "#4f79a9"; # glow border color
    shadow = "#000000"; # neutral shadow base
  };

in
{
  options.theme = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Unified Catppuccin Mocha palette available to all home-manager modules.";
  };

  config.theme = mocha // semantic;
}
