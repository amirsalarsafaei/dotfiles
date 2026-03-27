{ config, ... }:
let
  t = config.theme;
  hexByteToInt = byte: (builtins.fromTOML "value = 0x${byte}").value;
  hexToRgb = hex:
    let
      r = hexByteToInt (builtins.substring 1 2 hex);
      g = hexByteToInt (builtins.substring 3 2 hex);
      b = hexByteToInt (builtins.substring 5 2 hex);
    in
    "${toString r}, ${toString g}, ${toString b}";
  rgba = hex: a: "rgba(${hexToRgb hex}, ${toString a})";
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
        font-family: 'JetBrains Mono Nerd Font', 'Font Awesome 6 Free', sans-serif;
        font-size: 12px;
        font-weight: 600;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: transparent;
        color: ${t.fg};
      }

      tooltip {
        background: ${rgba t.glassStrong 0.95};
        border: 1px solid ${rgba t.glassBorder 0.4};
        border-radius: 10px;
      }
      tooltip label {
        color: ${t.fgBright};
      }

      .modules-left, .modules-right {
        background: ${rgba t.glassStrong 0.82};
        border: 1px solid ${rgba t.glassBorder 0.28};
        border-radius: 12px;
        padding: 3px 8px;
        margin-top: 6px;
        box-shadow: 0 6px 18px ${rgba t.shadow 0.35};
      }

      .modules-left { margin-left: 10px; }
      .modules-right { margin-right: 10px; }

      #workspaces {
        margin-right: 6px;
      }

      #workspaces button {
        padding: 0 8px;
        margin: 0 1px;
        background-color: transparent;
        color: ${t.muted};
        border-radius: 8px;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background: ${rgba t.surface 0.5};
        color: ${t.fgBright};
      }

      #workspaces button.active {
        background-color: ${rgba t.accent 0.24};
        border: 1px solid ${rgba t.accent 0.72};
        color: ${t.fgBright};
        font-weight: 700;
        min-width: 18px;
      }

      #workspaces button.visible {
        background-color: ${rgba t.accentAlt 0.16};
        color: ${t.fgBright};
      }

      #workspaces button.urgent {
        background-color: ${t.urgent};
        color: ${t.bgDark};
      }

      #workspaces button.empty {
        color: ${t.surface1};
      }

      #clock, #network, #wireplumber, #tray,
      #hyprland-language, #hardware, #custom-power,
      #cpu, #memory, #temperature, #battery {
        background-color: transparent;
        color: ${t.fg};
        padding: 0 8px;
        margin: 0 1px;
        border-radius: 8px;
        transition: all 0.2s ease;
      }

      #clock {
        font-weight: 800;
        color: ${t.fgBright};
        background-color: ${rgba t.surface 0.24};
      }

      #clock:hover,
      #network:hover,
      #wireplumber:hover,
      #custom-power:hover {
        background-color: ${rgba t.surface 0.34};
      }

      #network {
        color: ${t.subtle};
      }
      #network.disconnected { color: ${t.urgent}; }

      #wireplumber         { color: ${t.fg}; }
      #wireplumber.muted   { color: ${t.muted}; }

      #hardware {
        background-color: ${rgba t.surface 0.14};
        border: 1px solid ${rgba t.glassBorder 0.22};
        border-radius: 10px;
        padding: 0 4px;
        margin: 0 6px;
      }

      #cpu, #memory, #temperature, #battery {
        padding: 0 7px;
        color: ${t.subtext1};
      }

      #temperature.critical,
      #battery.warning:not(.charging) {
        color: ${t.warning};
      }

      #battery.charging, #battery.plugged { color: ${t.ok}; }

      #battery.critical:not(.charging) {
        color: ${t.urgent};
        animation-name: blink;
        animation-duration: 0.5s;
        animation-iteration-count: infinite;
      }

      @keyframes blink {
        to { color: ${t.fgBright}; }
      }

      #custom-power {
        color: ${t.accent};
        font-size: 14px;
        padding: 0 7px;
      }

      #hyprland-window {
        color: ${t.subtle};
        padding: 0 10px;
        font-weight: 500;
      }
    '';

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        margin-top = 0;
        margin-bottom = 0;

        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [];
        modules-right = [
          "clock"
          "network"
          "wireplumber"
          "group/hardware"
          "hyprland/language"
          "tray"
          "custom/power"
        ];

        network = {
          interval = 2;
          format-wifi = "  {essid}";
          format-ethernet = "󰈀  LAN";
          format-disconnected = "󰖪  Offline";
          tooltip-format = "IP: {ipaddr}\nDOWN: {bandwidthDownBytes} | UP: {bandwidthUpBytes}";
        };

        "group/hardware" = {
          orientation = "horizontal";
          modules = [ "cpu" "memory" "temperature" "battery" ];
        };

        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            urgent = "";
            active = "";
            visible = "󰮯";
            default = "";
            empty = "";
          };
          on-scroll-up = "hyprctl dispatch split-cycleworkspaces -1";
          on-scroll-down = "hyprctl dispatch split-cycleworkspaces +1";
          all-outputs = false;
        };

        "hyprland/window" = {
          max-length = 48;
          separate-outputs = true;
        };

        clock = {
          format = "󰅐 {:%H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            format = {
              months = "<span color='${t.fgBright}'><b>{}</b></span>";
              days = "<span color='${t.fg}'><b>{}</b></span>";
              weekdays = "<span color='${t.accent}'><b>{}</b></span>";
              today = "<span color='${t.urgent}'><b><u>{}</u></b></span>";
            };
          };
        };

        wireplumber = {
          format = "{icon}  {volume}%";
          format-muted = "󰝟  Muted";
          on-click = "pavucontrol";
          format-icons = [
            ""
            ""
            ""
          ];
        };

        cpu = {
          interval = 5;
          format = "  {usage}%";
        };

        memory = {
          interval = 5;
          format = "  {percentage}%";
        };

        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [
            ""
            ""
            ""
          ];
        };

        battery = {
          states = { warning = 30; critical = 15; };
          format = "{icon} {capacity}%";
          format-charging = "󱐋 {capacity}%";
          format-plugged = "󰚥 {capacity}%";
          format-icons = [
            "󰂎"
            "󰁻"
            "󰁽"
            "󰁿"
            "󰂁"
          ];
        };

        "hyprland/language" = {
          format = "󰌌 {}";
          format-en = "EN";
          format-fa = "FA";
        };

        tray = {
          icon-size = 15;
          spacing = 6;
        };

        "custom/power" = {
          format = "";
          tooltip = true;
          tooltip-format = "Lock with click · Suspend with right click";
          on-click = "loginctl lock-session";
          on-click-right = "systemctl suspend";
        };
      };
    };
  };
}
