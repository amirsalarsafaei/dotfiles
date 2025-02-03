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
      	xbacklight  -inc 10
      	;;
      	down)
      	xbacklight  -dec 10
      	;;
      esac

      notify-send -h int:value:$(xbacklight  -get) "Brightness"
    '')

    (writeShellScriptBin "backlight" ''
      #!/usr/bin/env bash
      case $1 in
      	up)
      	xbacklight -ctrl kbd_backlight -inc 20
      	;;
      	down)
      	xbacklight -ctrl kbd_backlight -dec 20
      	;;
      esac

      notify-send -h int:value:$(xbacklight -ctrl kbd_backlight -get) "Backlight"

    '')
  ];
}
