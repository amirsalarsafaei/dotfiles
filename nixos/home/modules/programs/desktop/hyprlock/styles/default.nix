{
  theme,
  themeLib,
  ...
}:
let
  t = theme.colors;
in
{
  settings = {
    background = {
      monitor = "";
      path = toString theme.wallpaper;
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
      outer_color = themeLib.rgba t.base0D 0.40;
      inner_color = themeLib.rgba t.base01 0.52;
      font_color = themeLib.rgba t.base05 0.9;
      fade_on_empty = false;
      font_family = theme.fonts.display;
      placeholder_text = "🔒  Enter Password";
      hide_input = false;
      position = "155, -210";
      halign = "left";
      valign = "center";
    };

    shape = {
      monitor = "";
      size = "340, 58";
      color = themeLib.rgba t.base00 0.38;
      rounding = -1;
      border_size = 1;
      border_color = themeLib.rgba t.base0E 0.55;
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
        color = ${themeLib.rgba t.base05 0.82}
        font_size = 50
        font_family = ${theme.fonts.display}
        position = 148, 320
        halign = left
        valign = center
    }

    label {
        monitor =
        text = cmd[update:1000] echo "<span>$(date +"%I:%M")</span>"
        color = ${themeLib.rgba t.base07 0.88}
        font_size = 40
        font_family = ${theme.fonts.display}
        position = 240, 240
        halign = left
        valign = center
    }

    label {
        monitor =
        text = cmd[update:1000] echo -e "$(date +"%A, %B %d")"
        color = ${themeLib.rgba t.base04 0.85}
        font_size = 19
        font_family = ${theme.fonts.display}
        position = 217, 175
        halign = left
        valign = center
    }

    label {
        monitor =
        text =     $USER
        color = ${themeLib.rgba t.base07 0.92}
        font_size = 16
        font_family = ${theme.fonts.display}
        position = 270, -130
        halign = left
        valign = center
    }

    label {
        monitor =
        text = cmd[update:1000] echo "$(${../Scripts/songdetail.sh})"
        color = ${themeLib.rgba t.base04 0.65}
        font_size = 14
        font_family = ${theme.fonts.mono}
        position = 210, 45
        halign = left
        valign = bottom
    }
  '';
}
