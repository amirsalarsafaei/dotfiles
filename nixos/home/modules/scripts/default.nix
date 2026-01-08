{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (writeShellScriptBin "volume" ''
      #!/usr/bin/env bash


      function get_volume {
          echo $(wpctl get-volume @DEFAULT_SINK@  | sed -e 's/[^0-9]*\([0-9]\+\)\.\([0-9]\+\)[^0-9]*/\1\2/g')
      }

      function is_mute {
           if [[ $(wpctl get-volume @DEFAULT_SINK@) == *"MUTED"* ]]; then
              return 0  # success, true (muted)
          else
              return 1  # failure, false (not muted)
          fi 
      }

      function send_notification {
      	volume=$(get_volume)
          if is_mute; then
              notify-send "Muted"
          else
              notify-send -h int:value:$volume "Volume"
          fi
      }

      case $1 in
          up)
          wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1
      	send_notification
      	;;
          down)
          wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      	send_notification
      	;;
          mute)
          wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      	if is_mute ; then
      	    dunstify -i audio-volume-muted-panel -t 8000 -r 2593 -u normal "Mute"
      	else
      	    send_notification
      	fi
      	;;
      esac


    '')

    (writeShellScriptBin "brightness" ''
      #!/usr/bin/env bash
      case $1 in
      	up)
      	brightnessctl set +10%
      	;;
      	down)
      	brightnessctl set 10%-
      	;;
      esac

      current=$(brightnessctl -m | cut -d',' -f4 | tr -d '%')
      notify-send -h int:value:$current "Brightness"
    '')

    (writeShellScriptBin "kbdbacklight" ''
      #!/usr/bin/env bash
      # Find keyboard backlight device (works across different systems)
      KBD_DEV=$(brightnessctl -l | grep -i kbd | head -1 | cut -d"'" -f2)

      if [ -z "$KBD_DEV" ]; then
        notify-send "Keyboard Backlight" "No keyboard backlight found"
        exit 1
      fi

      case $1 in
      	up)
      	brightnessctl -d "$KBD_DEV" set +20%
      	;;
      	down)
      	brightnessctl -d "$KBD_DEV" set 20%-
      	;;
      esac

      current=$(brightnessctl -d "$KBD_DEV" -m | cut -d',' -f4 | tr -d '%')
      notify-send -h int:value:$current "Keyboard Backlight"
    '')
  ];
}
