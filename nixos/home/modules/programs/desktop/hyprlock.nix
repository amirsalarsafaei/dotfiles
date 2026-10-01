{
  pkgs,
  lib,
  config,
  themeLib,
  funFortunes,
  ...
}:
let
  theme = config.custom.theme.resolved;
  t = theme.colors;
  s = theme.surfaces;
  a = theme.accents;

  hex = color: alpha: "rgba(${themeLib.stripHash color}${alpha})";
  muted = themeLib.mix t.base08 t.base02 30;

  info = pkgs.writeShellApplication {
    name = "hyprlock-info";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.playerctl
      pkgs.jcal
      pkgs.fortune
      pkgs.cowsay
    ];
    text = ''
      escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
      paint() { printf "<span foreground='%s'>%s</span>" "$1" "$2"; }

      battery() {
        local dir cap state icon
        for dir in /sys/class/power_supply/BAT*; do
          [ -r "$dir/capacity" ] || continue
          cap=$(cat "$dir/capacity")
          state=$(cat "$dir/status" 2>/dev/null || echo Unknown)
          if [ "$state" = Charging ]; then
            icon=$'\U000f0084'
          elif [ "$cap" -ge 90 ]; then
            icon=$'\U000f0079'
          elif [ "$cap" -ge 60 ]; then
            icon=$'\U000f007f'
          elif [ "$cap" -ge 30 ]; then
            icon=$'\U000f007c'
          else
            icon=$'\U000f007a'
          fi
          if [ "$cap" -le 20 ] && [ "$state" != Charging ]; then
            printf '%s  %s%%' "$(paint '${a.heat}' "$icon")" "$cap"
          else
            printf '%s  %s%%' "$(paint '${a.secondary}' "$icon")" "$cap"
          fi
          return
        done
      }

      media() {
        local state line
        state=$(playerctl status 2>/dev/null || true)
        [ "$state" = Playing ] || [ "$state" = Paused ] || return 0
        line=$(playerctl metadata --format '{{title}}{{#if artist}}  ·  {{artist}}{{/if}}' 2>/dev/null || true)
        [ -n "$line" ] || return 0
        [ "''${#line}" -le 56 ] || line="''${line:0:55}…"
        if [ "$state" = Playing ]; then
          printf '%s  %s' "$(paint '${a.primary}' $'\U000f075a')" "$(printf '%s' "$line" | escape)"
        else
          printf '%s  %s' "$(paint '${t.base03}' $'\U000f03e4')" "$(printf '%s' "$line" | escape)"
        fi
      }

      case "''${1:-}" in
        date)
          printf "<span letter_spacing='3072'>%s</span>" "$(date '+%A  ·  %-d %B' | tr '[:lower:]' '[:upper:]')"
          ;;
        jalali)
          printf "<span letter_spacing='1024'>%s</span>" "$(jdate '+%d %B %Y')"
          ;;
        host)
          read -r up _ </proc/uptime
          up=''${up%.*}
          printf '%s  %s   %s' "$(paint '${a.primary}' $'\U000f0322')" "$(cat /proc/sys/kernel/hostname)" \
            "$(paint '${t.base03}' "up $((up / 3600))h $((up % 3600 / 60))m")"
          ;;
        status)
          bat=$(battery)
          song=$(media)
          if [ -n "$bat" ] && [ -n "$song" ]; then
            printf '%s      %s' "$bat" "$song"
          else
            printf '%s%s' "$bat" "$song"
          fi
          ;;
        caps)
          for led in /sys/class/leds/*capslock*/brightness; do
            if [ "$(cat "$led" 2>/dev/null || echo 0)" = 1 ]; then
              printf "<span letter_spacing='2048'>%s  CAPS LOCK</span>" $'\U000f0632'
              break
            fi
          done
          ;;
        fortune)
          printf "<span font_features='calt=0,liga=0'>%s</span>" "$(fortune -s ${funFortunes} | cowsay -W 38 | escape)"
          ;;
      esac
    '';
  };

  run = command: "${lib.getExe info} ${command}";

  mkLabel =
    attrs:
    {
      monitor = "";
      font_family = theme.fonts.sans;
      halign = "center";
      valign = "center";
    }
    // attrs;
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        fail_timeout = 2500;
      };

      animations = {
        enabled = true;
        bezier = [
          "drawer, 0.16, 1, 0.3, 1"
          "steady, 1, 1, 0, 0"
        ];
        animation = [
          "fadeIn, 1, 5, drawer"
          "fadeOut, 1, 4, drawer"
          "inputFieldDots, 1, 2, steady"
          "inputFieldColors, 1, 4, drawer"
          "inputFieldWidth, 1, 3, drawer"
          "inputFieldFade, 1, 4, drawer"
        ];
      };

      background = [
        {
          monitor = "";
          path = "${theme.wallpaper}";
          color = hex s.ink "ff";
          blur_passes = 3;
          blur_size = 7;
          noise = 0.012;
          contrast = 0.9;
          brightness = 0.42;
          vibrancy = 0.12;
          vibrancy_darkness = 0.0;
        }
      ];

      shape = [
        {
          monitor = "";
          size = "44, 2";
          rounding = 1;
          color = hex a.primary "cc";
          position = "0, 14";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "380, 58";
          outline_thickness = 2;
          dots_size = 0.22;
          dots_spacing = 0.4;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "${hex a.border "ee"} ${hex s.line "ee"} 45deg";
          inner_color = hex s.ink "a6";
          font_color = hex t.base07 "ff";
          fade_on_empty = false;
          font_family = theme.fonts.mono;
          placeholder_text = "<span foreground='##${themeLib.stripHash t.base03}'>password</span>";
          hide_input = false;
          rounding = 16;
          check_color = "${hex a.secondary "ee"} ${hex a.primary "ee"} 45deg";
          fail_color = hex muted "ee";
          fail_text = "<span foreground='##${themeLib.stripHash t.base08}'>$FAIL  ($ATTEMPTS)</span>";
          capslock_color = hex a.heat "ee";
          shadow_passes = 2;
          shadow_size = 6;
          shadow_color = hex s.ink "99";
          position = "0, -110";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        (mkLabel {
          text = "cmd[update:60000] ${run "date"}";
          color = hex t.base04 "d9";
          font_size = 18;
          position = "0, 318";
        })
        (mkLabel {
          text = "$TIME";
          color = hex t.base07 "f2";
          font_size = 168;
          font_family = "${theme.fonts.display} Light";
          shadow_passes = 2;
          shadow_size = 8;
          shadow_color = hex s.ink "b3";
          position = "0, 168";
        })
        (mkLabel {
          text = "cmd[update:600000] ${run "jalali"}";
          color = hex a.secondary "e6";
          font_size = 16;
          font_family = theme.fonts.mono;
          position = "0, 44";
        })
        (mkLabel {
          text = "$USER";
          color = hex t.base05 "a6";
          font_size = 16;
          position = "0, -40";
        })
        (mkLabel {
          text = "$LAYOUT";
          color = hex t.base03 "cc";
          font_size = 13;
          font_family = theme.fonts.mono;
          position = "0, -172";
        })
        (mkLabel {
          text = "cmd[update:100] ${run "caps"}";
          color = hex a.heat "e6";
          font_size = 12;
          font_family = theme.fonts.mono;
          position = "0, -198";
        })
        (mkLabel {
          text = "cmd[update:60000] ${run "host"}";
          color = hex t.base04 "cc";
          font_size = 13;
          font_family = theme.fonts.mono;
          position = "48, -40";
          halign = "left";
          valign = "top";
        })
        (mkLabel {
          text = "cmd[update:2000] ${run "status"}";
          color = hex t.base04 "e6";
          font_size = 14;
          position = "48, 44";
          halign = "left";
          valign = "bottom";
          onclick = "${lib.getExe pkgs.playerctl} play-pause";
        })
        (mkLabel {
          text = "cmd[update:0] ${run "fortune"}";
          color = hex t.base04 "b3";
          font_size = 16;
          font_family = theme.fonts.mono;
          text_align = "left";
          position = "-48, 44";
          halign = "right";
          valign = "bottom";
        })
      ];
    };
  };
}
