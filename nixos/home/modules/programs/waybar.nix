{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      /* =============================================================================
       * CLASSY DARK GLASS THEME - REFINED
       * =========================================================================== */

      * {
        font-family: 'JetBrains Mono Nerd Font', 'Font Awesome 6 Free', sans-serif;
        font-size: 13px;
        font-weight: 600;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: transparent;
        /* No global background, allows transparency */
      }

      tooltip {
        background: #11111b;
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 10px;
      }
      tooltip label {
        color: #cdd6f4;
      }

      /* -----------------------------------------------------------------------------
       * Module Islands (The "Pills")
       * -------------------------------------------------------------------------- */
      .modules-left, .modules-right {
        background-color: rgba(17, 17, 27, 0.90); /* Deep matte black/grey */
        border: 1px solid rgba(255, 255, 255, 0.08); /* Very subtle border */
        border-radius: 20px; /* Fully rounded pill shape */
        padding: 4px 10px;
        margin-top: 6px; 
      }

      .modules-left {
        margin-left: 12px;
      }

      .modules-right {
        margin-right: 12px;
      }

      /* -----------------------------------------------------------------------------
       * Workspaces
       * -------------------------------------------------------------------------- */
      #workspaces button {
        padding: 0 10px;
        margin: 0 2px;
        background-color: transparent;
        color: #6c7086; /* Muted grey for inactive */
        border-radius: 15px;
        transition: all 0.3s ease;
      }

      #workspaces button:hover {
        background: rgba(255, 255, 255, 0.1);
        color: #ffffff;
      }

      #workspaces button.active {
        background-color: #cdd6f4; /* Bright White/Silver */
        color: #11111b; /* Dark text */
        font-weight: bold;
        min-width: 20px;
        box-shadow: 0 0 5px rgba(255, 255, 255, 0.2);
      }

      #workspaces button.urgent {
        background-color: #eba0ac; /* Soft Red */
        color: #11111b;
      }

      /* -----------------------------------------------------------------------------
       * Individual Modules - RESET COLORS
       * This section ensures we override the "rainbow" colors from the screenshot
       * -------------------------------------------------------------------------- */

      #clock, #network, #wireplumber, #tray, #hyprland-language, #hardware, #custom-power {
        background-color: transparent; /* IMPORTANT: Removes the blue/green/pink boxes */
        color: #cdd6f4; /* Unified text color */
        padding: 0 10px;
        margin: 0;
      }

      /* Specific Tweaks for visual hierarchy */

      #clock {
        font-weight: 800;
        color: #ffffff;
        margin-right: 4px;
      }

      #network {
        color: #a6adc8;
      }

      #network.disconnected {
        color: #f38ba8;
      }

      #wireplumber {
        color: #cdd6f4;
      }

      #wireplumber.muted {
        color: #9399b2;
      }

      /* -----------------------------------------------------------------------------
       * Hardware Group
       * -------------------------------------------------------------------------- */
      #hardware {
        /* Optional: a subtle background for the hardware stats specifically */
        background-color: rgba(255, 255, 255, 0.05); 
        border-radius: 10px;
        padding: 2px 8px;
        margin: 0 8px;
      }

      #cpu, #memory, #temperature, #battery {
        background-color: transparent;
        padding: 0 6px;
        color: #bac2de;
      }

      #battery.charging, #battery.plugged {
        color: #a6e3a1; /* Green hint when charging */
      }

      #battery.critical:not(.charging) {
        color: #f38ba8;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-iteration-count: infinite;
      }

      @keyframes blink {
        to { color: #ffffff; }
      }

      #hyprland-window {
        color: #a6adc8; /* Subtext color */
        padding: 0 15px;
        font-weight: 500;
      }
    '';

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40; # Slightly taller for elegance
        spacing = 0;
        margin-top = 0;
        margin-bottom = 0;

        # --- LEFT SIDE ---
        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];

        # --- CENTER ---
        modules-center = [ ];

        # --- RIGHT SIDE ---
        modules-right = [
          "clock"
          "network"
          "wireplumber"
          "group/hardware"
          "hyprland/language"
          "tray"
        ];

        # -- Network --
        network = {
          interval = 2;
          # Simplified format for cleaner look
          format-wifi = "   {essid}";
          format-ethernet = "󰈀  Ethernet";
          format-disconnected = "  Offline";
          tooltip-format = "IP: {ipaddr}\nDOWN: {bandwidthDownBytes} | UP: {bandwidthUpBytes}";
        };

        # -- Hardware Group --
        "group/hardware" = {
          orientation = "horizontal";
          modules = [
            "cpu"
            "memory"
            "battery"
          ];
        };

        # -- Modules --
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "default" = "";
          };
        };

        "hyprland/window" = {
          max-length = 40;
          separate-outputs = true;
        };

        clock = {
          format = "{:%H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            format = {
              months = "<span color='#ffffff'><b>{}</b></span>";
              days = "<span color='#cdd6f4'><b>{}</b></span>";
              weekdays = "<span color='#89b4fa'><b>{}</b></span>";
              today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
            };
          };
        };

        wireplumber = {
          format = "{icon} {volume}%";
          format-muted = " Muted";
          on-click = "pavucontrol";
          format-icons = [
            ""
            ""
            ""
          ];
        };

        cpu = {
          interval = 5;
          format = " {usage}%";
        };

        memory = {
          interval = 5;
          format = " {percentage}%";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };

        "hyprland/language" = {
          format = " {}";
          format-en = "EN";
          format-fa = "FA";
        };

        tray = {
          icon-size = 18;
          spacing = 10;
        };
      };
    };
  };
}
