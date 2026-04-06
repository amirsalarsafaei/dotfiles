{ t, ... }:
let
  hyprlock-assets = ../.;

  # hyprlock expects colours as "rgba(r, g, b, a)" or "rgb(r,g,b)".
  # We expose Catppuccin hex via t, and build the rgba strings here.
  # Helper: hex #rrggbb → "r, g, b"
  hexByteToInt = byte: (fromTOML "value = 0x${byte}").value;
  hexToRgb =
    hex:
    let
      r = hexByteToInt (builtins.substring 1 2 hex);
      g = hexByteToInt (builtins.substring 3 2 hex);
      b = hexByteToInt (builtins.substring 5 2 hex);
    in
    "${toString r}, ${toString g}, ${toString b}";

  rgba = hex: a: "rgba(${hexToRgb hex}, ${a})";

in
{
  settings = {
    background = {
      monitor = "";
      path = "${hyprlock-assets}/hyprlock.png";
      blur_passes = 2;
      contrast = 0.95;
      brightness = 0.85;
      vibrancy = 0.20;
      vibrancy_darkness = 0.0;
    };

    input-field = {
      monitor = "";
      size = "340, 58";
      outline_thickness = 2;
      dots_size = 0.2;
      dots_spacing = 0.2;
      dots_center = true;
      outer_color = "${rgba t.accent "0.40"}";
      inner_color = "${rgba t.glass "0.52"}";
      font_color = "${rgba t.fg "0.9"}";
      fade_on_empty = false;
      font_family = "SF Pro Display Bold";
      placeholder_text = "🔒  Enter Password";
      hide_input = false;
      position = "155, -210";
      halign = "left";
      valign = "center";
    };

    shape = {
      monitor = "";
      size = "340, 58";
      color = "${rgba t.glassStrong "0.38"}";
      rounding = -1;
      border_size = 1;
      border_color = "${rgba t.accentAlt "0.55"}";
      rotate = 0;
      xray = false;
      position = "155, -132";
      halign = "left";
      valign = "center";
    };
  };

  extraConfig = ''
    label {
        monitor =
        text = Welcome back
        color = ${rgba t.fg "0.82"}
        font_size = 50
        font_family = SF Pro Display Bold
        position = 148, 320
        halign = left
        valign = center
    }

    label {
        monitor =
        text = cmd[update:1000] echo "<span>$(date +"%I:%M")</span>"
        color = ${rgba t.fgBright "0.88"}
        font_size = 40
        font_family = SF Pro Display Bold
        position = 240, 240
        halign = left
        valign = center
    }

    label {
        monitor =
        text = cmd[update:1000] echo -e "$(date +"%A, %B %d")"
        color = ${rgba t.subtext0 "0.85"}
        font_size = 19
        font_family = SF Pro Display Bold
        position = 217, 175
        halign = left
        valign = center
    }

    label {
        monitor =
        text =     $USER
        color = ${rgba t.fgBright "0.92"}
        font_size = 16
        font_family = SF Pro Display Bold
        position = 270, -130
        halign = left
        valign = center
    }

    label {
        monitor =
        text = cmd[update:1000] echo "$(${hyprlock-assets}/Scripts/songdetail.sh)"
        color = ${rgba t.subtle "0.65"}
        font_size = 14
        font_family = JetBrains Mono Nerd Font
        position = 210, 45
        halign = left
        valign = bottom
    }
  '';
}
