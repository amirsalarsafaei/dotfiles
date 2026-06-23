{
  pkgs,
  config,
  themeLib,
  funFortunes,
  ...
}:
let
  theme = config.custom.theme.resolved;
  t = theme.colors;
in
{
  programs.hyprlock = {
    enable = true;
    package = pkgs.hyprlock;
    settings = {
      background = [
        {
          monitor = "";
          path = toString theme.wallpaper;
          blur_passes = 4;
          blur_size = 8;
          contrast = 0.85;
          brightness = 0.55;
          vibrancy = 0.10;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "400, 75";
          outline_thickness = 1;
          dots_size = 0.2;
          dots_spacing = 0.25;
          dots_center = true;
          dots_rounding = -1;
          outer_color = themeLib.rgba t.base03 0.30;
          inner_color = themeLib.rgba t.base00 0.35;
          font_color = themeLib.rgba t.base05 0.80;
          fade_on_empty = false;
          font_family = theme.fonts.mono;
          placeholder_text = "<span foreground='##${themeLib.stripHash t.base03}'>...</span>";
          hide_input = false;
          rounding = 20;
          check_color = themeLib.rgba t.base0B 0.50;
          fail_color = themeLib.rgba t.base08 0.60;
          fail_text = "<span foreground='##${themeLib.stripHash t.base08}'>$FAIL ($ATTEMPTS)</span>";
          capslock_color = themeLib.rgba t.base0A 0.50;
          position = "0, -30";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
          color = themeLib.rgba t.base07 0.95;
          font_size = 150;
          font_family = theme.fonts.mono;
          position = "0, -200";
          halign = "center";
          valign = "top";
        }
        {
          monitor = "";
          text = ''cmd[update:60000] echo "$(date +"%a %b %-d" | tr '[:lower:]' '[:upper:]')"'';
          color = themeLib.rgba t.base04 0.60;
          font_size = 30;
          font_family = theme.fonts.mono;
          position = "0, -430";
          halign = "center";
          valign = "top";
        }
        {
          monitor = "";
          text = ''cmd[update:43200000] echo "$(${pkgs.jcal}/bin/jdate '+%Y/%m/%d')"'';
          color = themeLib.rgba t.base05 1.0;
          font_size = 24;
          font_family = theme.fonts.mono;
          position = "0, -490"; # Adjust Y offset as needed
          halign = "center";
          valign = "top";
        }
        {
          monitor = "";
          text = "$USER";
          color = themeLib.rgba t.base05 0.55;
          font_size = 30;
          font_family = theme.fonts.mono;
          position = "0, 75";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:100] bash -c 'if [ "$(${pkgs.coreutils}/bin/cat /sys/class/leds/*capslock*/brightness 2>/dev/null || echo 0)" = "1" ]; then echo "CAPS"; fi' '';
          color = themeLib.rgba t.base0A 0.70;
          font_size = 15;
          font_family = theme.fonts.mono;
          position = "0, -80";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "$LAYOUT";
          color = themeLib.rgba t.base03 0.50;
          font_size = 18;
          font_family = theme.fonts.mono;
          position = "0, -100";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "cmd[update:0] ${pkgs.fortune}/bin/fortune -s ${funFortunes} | ${pkgs.cowsay}/bin/cowsay";
          color = themeLib.rgba t.base04 0.7;
          font_size = 25;
          font_family = theme.fonts.mono;
          text_align = "left";
          position = "0, 120";
          halign = "center";
          valign = "bottom";
        }
      ];
    };
  };
}
