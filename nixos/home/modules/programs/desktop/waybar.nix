{
  config,
  lib,
  themeLib,
  currentHostname,
  ...
}:
let
  t = config.custom.theme.resolved.colors;

  # waybar's battery module otherwise enumerates *every* /sys/class/power_supply
  # entry, including transient peripheral batteries — Logitech HID++ mice/keyboards
  # show up as `hidpp_battery_N`. When such a device sleeps or disconnects the node
  # vanishes mid-watch and waybar aborts the whole bar with an uncaught
  # std::runtime_error ("Could not watch events for ...") — Waybar #4871. Pinning
  # `bat` to the host's real internal battery makes waybar watch only that one node.
  # Add new laptops here; hosts absent from the map (desktops) drop the module.
  systemBattery =
    {
      mac = "macsmc-battery"; # Asahi / Apple Silicon
      g14 = "BAT0"; # ASUS ROG laptop (ACPI)
    }
    .${currentHostname} or "";
  hasBattery = systemBattery != "";
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
        font-family: 'JetBrainsMono Nerd Font', 'Font Awesome 6 Free', monospace;
        font-size: 14px;
        font-weight: 700;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: transparent;
        color: ${t.base05};
      }

      tooltip {
        background: ${themeLib.rgba t.base00 0.95};
        border: 1px solid ${themeLib.rgba t.base03 0.4};
        border-radius: 10px;
      }
      tooltip label {
        color: ${t.base07};
      }

      .modules-left, .modules-right {
        background: ${themeLib.rgba t.base00 0.82};
        border: 1px solid ${themeLib.rgba t.base03 0.32};
        border-radius: 12px;
        padding: 5px 12px;
        margin-top: 8px;
        box-shadow: 0 6px 18px ${themeLib.rgba t.base00 0.38};
      }

      .modules-left { margin-left: 12px; }
      .modules-right { margin-right: 12px; }

      #workspaces {
        margin-right: 6px;
      }

      #workspaces button {
        padding: 0 10px;
        margin: 0 2px;
        background-color: transparent;
        color: ${t.base04};
        border-radius: 9px;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background: ${themeLib.rgba t.base02 0.5};
        color: ${t.base07};
      }

      #workspaces button.active {
        background-color: ${themeLib.rgba t.base0D 0.24};
        border: 1px solid ${themeLib.rgba t.base0D 0.72};
        color: ${t.base07};
        font-weight: 700;
        min-width: 22px;
      }

      #workspaces button.visible {
        background-color: ${themeLib.rgba t.base0E 0.16};
        color: ${t.base07};
      }

      #workspaces button.urgent {
        background-color: ${t.base08};
        color: ${t.base00};
      }

      #workspaces button.empty {
        color: ${t.base03};
      }

      #idle_inhibitor {
        background-color: transparent;
        color: ${t.base04};
        padding: 0 10px;
        margin: 0 2px;
        border-radius: 9px;
        transition: all 0.2s ease;
      }
      #idle_inhibitor:hover {
        background-color: ${themeLib.rgba t.base02 0.34};
      }
      #idle_inhibitor.activated {
        color: ${t.base0D};
      }

      #clock, #network, #wireplumber, #tray,
      #hyprland-language, #hardware, #custom-power,
      #cpu, #memory, #temperature, #battery {
        background-color: transparent;
        color: ${t.base05};
        padding: 0 10px;
        margin: 0 2px;
        border-radius: 9px;
        transition: all 0.2s ease;
      }

      #clock {
        font-weight: 800;
        color: ${t.base07};
        background-color: ${themeLib.rgba t.base02 0.24};
      }

      #clock:hover,
      #network:hover,
      #wireplumber:hover,
      #custom-power:hover {
        background-color: ${themeLib.rgba t.base02 0.34};
      }

      #network {
        color: ${t.base04};
      }
      #network.disconnected { color: ${t.base08}; }

      #wireplumber         { color: ${t.base05}; }
      #wireplumber.muted   { color: ${t.base04}; }

      #hardware {
        background-color: ${themeLib.rgba t.base02 0.14};
        border: 1px solid ${themeLib.rgba t.base03 0.22};
        border-radius: 10px;
        padding: 0 4px;
        margin: 0 6px;
      }

      #cpu, #memory, #temperature, #battery {
        padding: 0 9px;
        color: ${t.base05};
      }

      #temperature.critical,
      #battery.warning:not(.charging) {
        color: ${t.base0A};
      }

      #battery.charging, #battery.plugged { color: ${t.base0B}; }

      #battery.critical:not(.charging) {
        color: ${t.base08};
        animation-name: blink;
        animation-duration: 0.5s;
        animation-iteration-count: infinite;
      }

      @keyframes blink {
        to { color: ${t.base07}; }
      }

      #custom-power {
        color: ${t.base0D};
        font-size: 16px;
        padding: 0 9px;
      }

      #hyprland-window {
        color: ${t.base04};
        padding: 0 12px;
        font-weight: 600;
      }

      /* Submap (mode) indicator — bright pill so the active mode is obvious */
      #submap {
        color: ${t.base00};
        background-color: ${t.base0A};
        padding: 0 16px;
        margin: 0 4px;
        border-radius: 10px;
        font-weight: 800;
      }
    '';

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 42;
        spacing = 6;
        margin-top = 0;
        margin-bottom = 0;

        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
          "tray"
          "network"
          "idle_inhibitor"
        ];
        modules-center = [ "hyprland/submap" ];
        modules-right = [
          "clock"
          "wireplumber"
          "group/hardware"
          "hyprland/language"
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
          modules = [
            "cpu"
            "memory"
            "temperature"
          ]
          ++ lib.optional hasBattery "battery";
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

        # Active submap indicator (e.g. SUPER+M -> move, SUPER+R -> resize).
        # Auto-hides when back in the default submap.
        "hyprland/submap" = {
          format = "  {}";
          max-length = 24;
          tooltip = false;
        };

        clock = {
          format = "󰅐 {:%H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            format = {
              months = "<span color='${t.base07}'><b>{}</b></span>";
              days = "<span color='${t.base05}'><b>{}</b></span>";
              weekdays = "<span color='${t.base0D}'><b>{}</b></span>";
              today = "<span color='${t.base08}'><b><u>{}</u></b></span>";
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
          # Pin to the host's real battery so the module never watches a
          # peripheral's transient power_supply node (see systemBattery above).
          bat = systemBattery;
          states = {
            warning = 30;
            critical = 15;
          };
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

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰛊";
            deactivated = "󰾪";
          };
          tooltip-format-activated = "Idle inhibitor: ON";
          tooltip-format-deactivated = "Idle inhibitor: OFF";
        };

        tray = {
          icon-size = 18;
          spacing = 4;
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
