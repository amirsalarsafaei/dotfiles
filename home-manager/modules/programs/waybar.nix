{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      /* =============================================================================
       *
       * Waybar configuration
       *
       * Configuration reference: https://github.com/Alexays/Waybar/wiki/Configuration
       *
       * =========================================================================== */

      /* -----------------------------------------------------------------------------
       * Keyframes
       * -------------------------------------------------------------------------- */

      @keyframes blink-warning {
        70% {
          color: white;
        }

        to {
          color: white;
          background-color: orange;
        }
      }

      @keyframes blink-critical {
        70% {
          color: white;
        }

        to {
          color: white;
          background-color: red;
        }
      }


      /* -----------------------------------------------------------------------------
       * Base styles
       * -------------------------------------------------------------------------- */

      /* Reset all styles */
      * {
        border: none;
        border-radius: 0;
        min-height: 0;
        margin: 0;
        padding: 0;
        transition: all 0.3s ease;
      }

      /* The whole bar */
      #waybar {
        background: transparent;
        color: #c0caf5;
        font-family: 'JetBrains Mono Nerd Font', Cantarell, Noto Sans, sans-serif;
        font-size: 13px;
        margin: 5px 5px;
      }

      .modules-right {
        margin-right: 5px;
        border-radius: 12px;
        background: linear-gradient(45deg, #1a1b26 0%, #24283b 100%);
        box-shadow: rgba(0, 0, 0, 0.116) 2px 2px 4px 2px;
      padding: 3px;
      margin: 5px;
            }
      
            .modules-left {
      margin-left: 5px;
      border-radius: 12px;
      background: linear-gradient(45deg, #1a1b26 0%, #24283b 100%);
      box-shadow: rgba(0, 0, 0, 0.116) 2px 2px 4px 2px;
      padding: 3px;
      margin: 5px;
      }

      /* Each module */
      #battery,
      #clock,
      #cpu,
      #custom-keyboard-layout,
      #memory,
      #mode,
      #network,
      #pulseaudio,
      #temperature,
      #tray,
      #keyboard-state,
      #keyboard-state label,
      #hyprland-language {
        padding: 0 8px;
        margin: 3px;
        border-radius: 12px;
        background: rgba(36, 40, 59, 0.4);
        color: #c0caf5;
      font-weight: bold;
            }
      
            /* Add separators between modules */
            #battery,
            #cpu,
            #memory,
            #temperature,
            #wireplumber,
            #keyboard-state,
            #hyprland-language {
      border-right: 1px solid rgba(192, 202, 245, 0.1);
      padding-right: 10px;
      margin-right: 5px;
      }

      #battery:hover,
      #clock:hover,
      #cpu:hover,
      #custom-keyboard-layout:hover,
      #memory:hover,
      #network:hover,
      #pulseaudio:hover,
      #temperature:hover {
        background: rgba(36, 40, 59, 0.8);
        box-shadow: rgba(0, 0, 0, 0.116) 2px 2px 4px 2px;
      }


      /* -----------------------------------------------------------------------------
       * Module styles
       * -------------------------------------------------------------------------- */

      #battery {
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      #battery.warning {
        color: #e0af68;
        background: rgba(224, 175, 104, 0.2);
      }

      #battery.critical {
        color: #f7768e;
        background: rgba(247, 118, 142, 0.2);
      }

      #battery.warning.discharging {
        animation-name: blink-warning;
        animation-duration: 3s;
      }

      #battery.critical.discharging {
        animation-name: blink-critical;
        animation-duration: 2s;
      }

      #clock {
        font-weight: bold;
        color: #7aa2f7;
        background: rgba(122, 162, 247, 0.2);
      }

      #cpu {
        /* No styles */
      }

      #cpu.warning {
        color: orange;
      }

      #cpu.critical {
        color: red;
      }

      #memory {
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      #memory.warning {
        color: orange;
      }

      #memory.critical {
        color: red;
        animation-name: blink-critical;
        animation-duration: 2s;
      }

      #mode {
        background: #64727D;
        border-top: 2px solid white;
        /* To compensate for the top border and still have vertical centering */
        padding-bottom: 2px;
      }

      #network {
        /* No styles */
      }

      #network.disconnected {
        color: orange;
      }

      #pulseaudio {
        /* No styles */
      }

      #pulseaudio.muted {
        /* No styles */
      }

      #custom-spotify {
        color: #9ece6a;
        background: rgba(158, 206, 106, 0.2);
        border-radius: 8px;
        padding: 0 12px;
        margin: 4px 4px;
      }

      #custom-spotify:hover {
        background: rgba(158, 206, 106, 0.3);
        box-shadow: rgba(0, 0, 0, 0.116) 2px 2px 4px 2px;
      }

      #temperature {
        /* No styles */
      }

      #temperature.critical {
        color: red;
      }

      #keyboard-state {
        background: rgba(122, 162, 247, 0.2);
        color: #7aa2f7;
        margin-right: 8px;
        padding: 0 8px;
        min-width: 16px;
      }

      #keyboard-state label {
        padding: 0 2px;
      }

      #keyboard-state label.locked {
        background: rgba(247, 118, 142, 0.2);
        color: #f7768e;
      }

      #hyprland-language {
        background: rgba(158, 206, 106, 0.2);
        color: #9ece6a;
        padding: 0 8px;
        margin: 4px 4px;
      }

      #tray {
        background: rgba(36, 40, 59, 0.4);
        margin: 4px 4px;
        padding: 0 8px;
      }

      #window {
        font-weight: bold;
      }

      #workspaces button {
        padding: 0 10px;
        margin: 4px 4px;
        border-radius: 12px;
        background: rgba(36, 40, 59, 0.4);
        color: #565f89;
        font-weight: bold;
        transition: all 0.3s ease;
      min-width: 35px;
      font-size: 15px;
      }

      #workspaces button.active {
        background: rgba(122, 162, 247, 0.2);
        color: #7aa2f7;
        box-shadow: inset 0 0 0 2px rgba(122, 162, 247, 0.2);
      }

      #workspaces button.focused {
        background: rgba(122, 162, 247, 0.7);
        color: #ffffff;
        text-shadow: 0 0 5px rgba(122, 162, 247, 0.7);
        box-shadow: rgba(122, 162, 247, 0.25) 0px 4px 8px;
        padding: 0 15px;
        box-shadow: inset 0 0 0 2px rgba(122, 162, 247, 0.4);
      }

      #workspaces button.urgent {
        background: rgba(247, 118, 142, 0.7);
        color: #ffffff;
        text-shadow: 0 0 5px rgba(247, 118, 142, 0.7);
        box-shadow: rgba(247, 118, 142, 0.25) 0px 4px 8px;
      }

      #workspaces button:hover {
        background: rgba(36, 40, 59, 0.8);
        color: #c0caf5;
        box-shadow: inset 0 0 0 2px rgba(192, 202, 245, 0.3),
                    rgba(0, 0, 0, 0.15) 0px 4px 8px;
        padding: 0 15px;
      }
    '';
    settings = {
      mainBar =
        {
          layer = "top";
          exclusive = true;
          battery = {
            format = "  {capacity}%";
            format-charging = "󰢝  {capacity}%";
            format-plugged = "  {capacity}%";
            interval = 30;
          };
          clock = {
            format = "{:%H:%M:%S}";
            interval = 1;
          };
          cpu = {
            format = "  {usage}%";
            interval = 5;
          };
          "custom/absclock" = {
            exec = "date +%s";
            format = "{}";
            interval = 1;
            return-type = "{}";
          };
          "custom/loadavg" = {
            exec = "cat /proc/loadavg | head -c 14";
            format = "Load average: {}";
            interval = 1;
            return-type = "{}";
          };
          "custom/uptime" = {
            exec = "uptime -p | sed 's/up //g' -";
            format = "Uptime: {}";
            interval = 60;
            return-type = "{}";
          };
          height = 33;
          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = "Don't idle";
              deactivated = "Idling";
            };
          };
          memory = {
            format = "  {}%";
            interval = 5;
          };
          "hyprland/window" = {
            format = "{}";
            max-length = 30;
          };
          modules-center = [ ];
          modules-left = [ "hyprland/workspaces" "network" "hyprland/window" "tray" ];
          modules-right = [
            "group/hardware"
            "group/indicators"
          ];
          "group/hardware" = {
            orientation = "horizontal";
            modules = [
              "temperature"
              "cpu"
              "memory"
              "battery"
            ];
          };
          "group/indicators" = {
            orientation = "horizontal";
            modules = [
              "wireplumber"
              "keyboard-state"
              "hyprland/language"
              "clock"
            ];
          };
          network = {
            format = "Net via {ifname}";
            format-disconnected = "No net";
            format-wifi = "{essid} ({signalStrength}%)  ";
            tooltip-format = "{ipaddr}/{cidr}";
          };
          position = "top";
          temperature = {
            format = " {temperatureC}°C";
            interval = 1;
          };
          tray = {
            spacing = 10;
          };
          wireplumber = {
            format = "  {volume}%";
            format-muted = " mute";
            on-click = "pavucontrol";
            scroll-step = 1;
          };
          keyboard-state = {
            capslock = true;
            numlock = true;
            format = {
              capslock = "󰪛 {name}";
              numlock = "󰎠 {name}";
            };
            format-icons = {
              locked = "";
              unlocked = "";
            };
          };
          "hyprland/workspaces" = {
            persistent-workspaces = {
              "eDP-2" = [ 1 2 3 4 5 ];
              "eDP-1" = [ 1 2 3 4 5 ];
              "DP-1" = [ 6 7 8 9 ];
              "HDMI-A-1" = [ 6 7 8 9 ];
            };
            format = "{icon}";
            format-icons = {
              "1" = "󰆍"; # Terminal/Dev
              "2" = "󰈹"; # Web Browser
              "3" = "󰭹"; # Chat/Social
              "4" = "󰒓"; # Games
              "5" = "󰉋"; # Files
              "6" = "󰆍"; # Music
              "7" = "󰈹"; # Video/Media
              "8" = "󰭹"; # Settings
              "9" = "󰒓"; # Downloads/Misc
            };
          };
        };

    };
  };
}
