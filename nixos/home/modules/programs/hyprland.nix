{
  inputs,
  pkgs,
  osConfig,
  ...
}:
let
  monitorConfig = osConfig.custom.hyprland.monitorConfig or ",preferred,auto,auto";
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    extraConfig = ''
      # Hyprland Configuration

      $terminal = ghostty
      $fileManager = dolphin
      $menu = rofi -show drun -run-command 'uwsm app -- {cmd}'
      $clipboard = rofi-cliphist-paste

      env = XCURSOR_SIZE,24
      env = HYPRCURSOR_SIZE,24
      env = XDG_MENU_PREFIX,plasma-

      # Monitor configuration
      monitor = ${monitorConfig}

      general {
          gaps_in = 5
          gaps_out = 10
          border_size = 2
          col.active_border = rgba(4a90e2ee) rgba(6bb6ffee) 45deg
          col.inactive_border = rgba(b0c4debb)
          resize_on_border = false
          allow_tearing = false
          layout = dwindle
      }

      gesture = 3, horizontal, workspace

      decoration {
          rounding = 5
          active_opacity = 1.0
          inactive_opacity = 1

          blur {
              enabled = true
              size = 4
              passes = 2
              special = true
              vibrancy = 0.15
          }
      }

      animations {
          enabled = true
          animation = windows, 1, 4, default
          animation = windowsOut, 1, 4, default, popin 90%
          animation = border, 1, 6, default
          animation = fade, 1, 4, default
          animation = workspaces, 1, 4, default
      }

      dwindle {
          pseudotile = true
          preserve_split = true
      }

      master {
          new_status = master
      }

      misc {
          force_default_wallpaper = -1
          disable_hyprland_logo = false
      }

      input {
          kb_layout = us,ir
          kb_options = grp:win_space_toggle
          follow_mouse = 0
          sensitivity = 0
          
          touchpad {
              natural_scroll = false
          }
      }

      device {
          name = epic-mouse-v1
          sensitivity = -0.5
      }

      bindm = SUPER, mouse:272, movewindow
      bindm = SUPER, mouse:273, resizewindow

      bind = SUPER, RETURN, exec, $terminal
      bind = SUPER, w, killactive
      bind = SUPER, x, exec, hyprlock
      bind = SUPER_SHIFT, Q, exit
      bind = SUPER_SHIFT, f, togglefloating
      bind = SUPER, f, fullscreen, 1
      bind = CTRL, SPACE, exec, $menu
      bind = SUPER, P, pseudo
      bind = SUPER, t, togglesplit

      bind = SUPER, h, movefocus, l
      bind = SUPER, l, movefocus, r
      bind = SUPER, k, movefocus, u
      bind = SUPER, j, movefocus, d

      bind = SUPER_SHIFT, h, swapwindow, l
      bind = SUPER_SHIFT, l, swapwindow, r
      bind = SUPER_SHIFT, k, swapwindow, u
      bind = SUPER_SHIFT, j, swapwindow, d

      binde = SUPER_ALT, h, resizeactive, -40 0
      binde = SUPER_ALT, l, resizeactive, 40 0
      binde = SUPER_ALT, k, resizeactive, 0 -40
      binde = SUPER_ALT, j, resizeactive, 0 40

      bind = SUPER, M, submap, move
      submap = move
      binde = , h, moveactive, -40 0
      binde = , l, moveactive, 40 0
      binde = , k, moveactive, 0 -40
      binde = , j, moveactive, 0 40
      binde = SHIFT, h, moveactive, -10 0
      binde = SHIFT, l, moveactive, 10 0
      binde = SHIFT, k, moveactive, 0 -10
      binde = SHIFT, j, moveactive, 0 10
      binde = CTRL, h, moveactive, -100 0
      binde = CTRL, l, moveactive, 100 0
      binde = CTRL, k, moveactive, 0 -100
      binde = CTRL, j, moveactive, 0 100
      bind = , escape, submap, reset
      bind = , RETURN, submap, reset
      bind = SUPER, M, submap, reset
      submap = reset

      bind = SUPER, R, submap, resize
      submap = resize
      binde = , h, resizeactive, -40 0
      binde = , l, resizeactive, 40 0
      binde = , k, resizeactive, 0 -40
      binde = , j, resizeactive, 0 40
      binde = SHIFT, h, resizeactive, -10 0
      binde = SHIFT, l, resizeactive, 10 0
      binde = SHIFT, k, resizeactive, 0 -10
      binde = SHIFT, j, resizeactive, 0 10
      binde = CTRL, h, resizeactive, -100 0
      binde = CTRL, l, resizeactive, 100 0
      binde = CTRL, k, resizeactive, 0 -100
      binde = CTRL, j, resizeactive, 0 100
      bind = , escape, submap, reset
      bind = , RETURN, submap, reset
      bind = SUPER, R, submap, reset
      submap = reset

      bind = SUPER, 1, workspace, 1
      bind = SUPER, 2, workspace, 2
      bind = SUPER, 3, workspace, 3
      bind = SUPER, 4, workspace, 4
      bind = SUPER, 5, workspace, 5
      bind = SUPER, 6, workspace, 6
      bind = SUPER, 7, workspace, 7
      bind = SUPER, 8, workspace, 8
      bind = SUPER, 9, workspace, 9
      bind = SUPER, 0, workspace, 10

      bind = SUPER_SHIFT, 1, movetoworkspace, 1
      bind = SUPER_SHIFT, 2, movetoworkspace, 2
      bind = SUPER_SHIFT, 3, movetoworkspace, 3
      bind = SUPER_SHIFT, 4, movetoworkspace, 4
      bind = SUPER_SHIFT, 5, movetoworkspace, 5
      bind = SUPER_SHIFT, 6, movetoworkspace, 6
      bind = SUPER_SHIFT, 7, movetoworkspace, 7
      bind = SUPER_SHIFT, 8, movetoworkspace, 8
      bind = SUPER_SHIFT, 9, movetoworkspace, 9
      bind = SUPER_SHIFT, 0, movetoworkspace, 10

      bind = SUPER, S, togglespecialworkspace, magic
      bind = SUPER_SHIFT, S, movetoworkspace, special:magic

      bind = SUPER, v, exec, $clipboard
      bind = SUPER_SHIFT, v, exec, rofi-cliphist-delete
      bind = SUPER_CTRL, v, exec, cliphist-clear

      bind = SUPER, mouse_down, workspace, e+1
      bind = SUPER, mouse_up, workspace, e-1

      bind = SUPER_CTRL, 1, workspace, 1
      bind = SUPER_CTRL, 2, workspace, 2
      bind = SUPER_CTRL, 3, workspace, 3
      bind = SUPER_CTRL, 4, workspace, 4
      bind = SUPER_CTRL, 5, workspace, 5
      bind = SUPER_CTRL, 6, workspace, 6
      bind = SUPER_CTRL, 7, workspace, 7
      bind = SUPER_CTRL, 8, workspace, 8
      bind = SUPER_CTRL, 9, workspace, 9
      bind = SUPER_CTRL, 0, workspace, 10

      bind = SUPER_CTRL, F1, workspace, 11
      bind = SUPER_CTRL, F2, workspace, 12
      bind = SUPER_CTRL, F3, workspace, 13

      bind = SUPER, comma, focusmonitor, -1
      bind = SUPER, period, focusmonitor, +1

      bind = SUPER_SHIFT, comma, movecurrentworkspacetomonitor, -1
      bind = SUPER_SHIFT, period, movecurrentworkspacetomonitor, +1

      bind = SUPER_ALT, 1, focusworkspaceoncurrentmonitor, 1
      bind = SUPER_ALT, 2, focusworkspaceoncurrentmonitor, 2
      bind = SUPER_ALT, 3, focusworkspaceoncurrentmonitor, 3
      bind = SUPER_ALT, 4, focusworkspaceoncurrentmonitor, 4
      bind = SUPER_ALT, 5, focusworkspaceoncurrentmonitor, 5
      bind = SUPER_ALT, 6, focusworkspaceoncurrentmonitor, 6
      bind = SUPER_ALT, 7, focusworkspaceoncurrentmonitor, 7
      bind = SUPER_ALT, 8, focusworkspaceoncurrentmonitor, 8
      bind = SUPER_ALT, 9, focusworkspaceoncurrentmonitor, 9
      bind = SUPER_ALT, 0, focusworkspaceoncurrentmonitor, 10

      bindel = , XF86AudioRaiseVolume, exec, volume up
      bindel = , XF86AudioLowerVolume, exec, volume down
      bindel = , XF86AudioMute, exec, volume mute
      bindel = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bindel = , XF86MonBrightnessUp, exec, brightness up
      bindel = , XF86MonBrightnessDown, exec, brightness down
      bindel = , XF86LaunchA, exec, kbdbacklight down
      bindel = SUPER, XF86LaunchA, exec, kbdbacklight up
      bindel = , XF86KbdBrightnessDown, exec, kbdbacklight down
      bindel = , XF86KbdBrightnessUp, exec, kbdbacklight up
      bindel = , XF86Launch1, exec, rog-control-center

      bindel = , Print, exec, grim -g "$(slurp)" - | wl-copy
      bindel = , XF86Print, exec, grim -g "$(slurp)" - | wl-copy
      bindel = SHIFT, Print, exec, grim - | wl-copy
      bindel = SHIFT, XF86Print, exec, grim - | wl-copy
      bindel = SHIFT_ALT, F3, exec, grim - | wl-copy
      bindel = SHIFT_ALT, F4, exec, grim -g "$(slurp)" - | wl-copy

      xwayland {
          force_zero_scaling = true
      }

      # windowrule = suppressevent maximize, match:class:.*
      # windowrule = opacity 1.0 override 1.0 override, match:class:^(vlc|firefox|chromium-browser|jetbrains-.*)$
      # windowrule = bordercolor rgba(87ceebee) rgba(87ceebee), match:class:^(jetbrains-.*)$
      # windowrule = animation none, match:class:^(jetbrains-.*)$
      # windowrule = nofocus, match:class:^jetbrains-(?!toolbox), floating:1, title:^win\d+$
      # windowrule = float, match:class:^(jetbrains-.*)$, title:^(win[0-9]+)$
      # windowrule = nofocus, match:class:^(jetbrains-.*)$, title:^(win[0-9]+)$

    '';
  };
}
