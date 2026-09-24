{
  config,
  lib,
  pkgs,
  themeLib,
  currentHostname,
  osConfig,
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
      g14 = "BAT1"; # ASUS ROG laptop (ACPI)
      t14 = "BAT0"; # Lenovo ThinkPad (ACPI)
    }
    .${currentHostname} or "";
  hasBattery = systemBattery != "";
  hasPowerProfiles = osConfig.services.power-profiles-daemon.enable or false;

  cpuTemperature =
    {
      t14 = {
        hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
        input-filename = "temp1_input";
      };
    }
    .${currentHostname} or { };

  compactOutput = osConfig.hyprland.compactOutput or null;

  comfy = {
    fontSize = 12;
    height = 34;
    spacing = 6;
    marginTop = 4;
    marginSide = 10;
    barRadius = 16;
    edge = 12;
    pad = "3px 8px";
    buttonPad = "2px 9px";
    powerFont = 16;
    powerPad = "4px 12px";
    trayIcon = 18;
    clockPad = "3px 10px";
    groupPad = "2px 5px";
    itemPad = "2px 9px";
    submapPad = "4px 16px";
    windowLength = 48;
  };

  tight = {
    fontSize = 11;
    height = 28;
    spacing = 3;
    marginTop = 3;
    marginSide = 6;
    barRadius = 14;
    edge = 8;
    pad = "2px 7px";
    buttonPad = "1px 7px";
    powerFont = 14;
    powerPad = "2px 10px";
    trayIcon = 16;
    clockPad = "2px 9px";
    groupPad = "1px 4px";
    itemPad = "1px 7px";
    submapPad = "2px 12px";
    windowLength = 36;
  };

  tightCss = ''
    window#waybar.waybar-compact,
    window#waybar.waybar-compact * {
      font-size: ${toString tight.fontSize}px;
    }
    window#waybar.waybar-compact { border-radius: ${toString tight.barRadius}px; }
    window#waybar.waybar-compact .modules-left { margin-left: ${toString tight.edge}px; }
    window#waybar.waybar-compact .modules-right { margin-right: ${toString tight.edge}px; }
    window#waybar.waybar-compact #workspaces,
    window#waybar.waybar-compact #idle_inhibitor,
    window#waybar.waybar-compact #clock,
    window#waybar.waybar-compact #custom-jalali,
    window#waybar.waybar-compact #custom-gregorian,
    window#waybar.waybar-compact #network,
    window#waybar.waybar-compact #wireplumber,
    window#waybar.waybar-compact #tray,
    window#waybar.waybar-compact #hyprland-language,
    window#waybar.waybar-compact #power-profiles-daemon,
    window#waybar.waybar-compact #battery,
    window#waybar.waybar-compact #hyprland-window {
      padding: ${tight.pad};
    }
    window#waybar.waybar-compact #workspaces button { padding: ${tight.buttonPad}; }
    window#waybar.waybar-compact #clock { padding: ${tight.clockPad}; }
    window#waybar.waybar-compact #hardware { padding: ${tight.groupPad}; }
    window#waybar.waybar-compact #cpu,
    window#waybar.waybar-compact #memory,
    window#waybar.waybar-compact #temperature {
      padding: ${tight.itemPad};
    }
    window#waybar.waybar-compact #custom-power {
      font-size: ${toString tight.powerFont}px;
      padding: ${tight.powerPad};
    }
    window#waybar.waybar-compact #submap { padding: ${tight.submapPad}; }
  '';

  waybarToggle = pkgs.writeShellApplication {
    name = "waybar-toggle";
    runtimeInputs = [
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      visible() {
        hyprctl layers -j \
          | jq -e '[.. | objects | select((.namespace? // "") | startswith("waybar"))] | length > 0' >/dev/null
      }

      want="''${1:-toggle}"
      if [ "$want" = toggle ]; then
        if visible; then want=hide; else want=show; fi
      fi
      case "$want" in
        hide) visible || exit 0 ;;
        show) visible && exit 0 ;;
        *)
          echo "usage: waybar-toggle [toggle|show|hide]" >&2
          exit 2
          ;;
      esac
      systemctl --user kill --signal=SIGUSR1 waybar.service
    '';
  };
in
{
  home.packages = [ waybarToggle ];

  custom.keys.commands.waybarToggle = lib.getExe waybarToggle;

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
        font-family: 'JetBrainsMono Nerd Font', 'Font Awesome 6 Free', monospace;
        font-size: ${toString comfy.fontSize}px;
        font-weight: 700;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      /* One continuous bar, floating clear of the screen edges (see mainBar
         margin below) so it reads as a rounded pill over the wallpaper
         instead of a flat rectangle glued to the top edge. The surface
         carries the background, and that translucency is what the
         compositor's layer rule blurs (see the `waybar` layerrule in
         hyprland.nix), so the bar reads as glass, not a flat strip. */
      window#waybar {
        background: ${themeLib.rgba t.base00 0.86};
        border-radius: ${toString comfy.barRadius}px;
        border: 1px solid ${themeLib.rgba t.base0D 0.4};
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

      /* Modules share one bar now, so only the outer edges need a gutter. */
      .modules-left { margin-left: ${toString comfy.edge}px; }
      .modules-right { margin-right: ${toString comfy.edge}px; }

      /* Shared pill geometry for every standalone module: identical padding
         keeps the hover highlights and the clock/group accents aligned. */
      #workspaces,
      #idle_inhibitor,
      #clock,
      #custom-jalali,
      #custom-gregorian,
      #network,
      #wireplumber,
      #tray,
      #hyprland-language,
      #power-profiles-daemon,
      #custom-power,
      #battery,
      #hyprland-window {
        background-color: transparent;
        color: ${t.base05};
        padding: ${comfy.pad};
        margin: 0 2px;
        border-radius: 10px;
        transition: background-color 0.2s ease, color 0.2s ease, border-color 0.2s ease;
      }

      #workspaces {
        padding: ${comfy.pad};
        margin-right: 4px;
      }

      #workspaces button {
        padding: ${comfy.buttonPad};
        margin: 0 2px;
        background-color: transparent;
        color: ${t.base04};
        border-radius: 8px;
        transition: background-color 0.2s ease, color 0.2s ease, border-color 0.2s ease;
      }

      #workspaces button:hover {
        background: ${themeLib.rgba t.base02 0.5};
        color: ${t.base07};
      }

      #workspaces button.active {
        background-color: ${themeLib.rgba t.base0D 0.26};
        border: 1px solid ${themeLib.rgba t.base0D 0.75};
        box-shadow: 0 0 8px ${themeLib.rgba t.base0D 0.45};
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

      #idle_inhibitor           { color: ${t.base04}; }
      #idle_inhibitor.activated { color: ${t.base0D}; }

      /* Hover feedback is shared so no module reads as inert. A slight lift
         reads as "clickable" without needing a border on every pill. */
      #idle_inhibitor:hover,
      #clock:hover,
      #network:hover,
      #wireplumber:hover,
      #hyprland-language:hover,
      #power-profiles-daemon:hover,
      #custom-power:hover,
      #battery:hover {
        background-color: ${themeLib.rgba t.base02 0.34};
      }

      #clock {
        font-weight: 800;
        color: ${t.base07};
        background: linear-gradient(
          135deg,
          ${themeLib.rgba t.base0D 0.28},
          ${themeLib.rgba t.base02 0.3}
        );
        border: 1px solid ${themeLib.rgba t.base0D 0.3};
        padding: ${comfy.clockPad};
        letter-spacing: 0.02em;
      }

      /* Each module gets its own accent color so the right-hand cluster reads
         as distinct icons at a glance instead of one grey block of text. */
      #network              { color: ${t.base0C}; }
      #network.disconnected { color: ${t.base08}; }

      #wireplumber          { color: ${t.base0B}; }
      #wireplumber.muted    { color: ${t.base04}; }

      #hyprland-language { color: ${t.base0A}; }

      #power-profiles-daemon.performance { color: ${t.base08}; }
      #power-profiles-daemon.balanced { color: ${t.base0D}; }
      #power-profiles-daemon.power-saver { color: ${t.base0B}; }

      /* CPU/memory/temperature read as one inset group. */
      #hardware {
        background-color: ${themeLib.rgba t.base02 0.14};
        border: 1px solid ${themeLib.rgba t.base03 0.22};
        border-radius: 12px;
        padding: ${comfy.groupPad};
        margin: 0 6px;
      }

      #cpu, #memory, #temperature {
        padding: ${comfy.itemPad};
        border-radius: 8px;
      }

      #cpu         { color: ${t.base0C}; }
      #memory      { color: ${t.base0B}; }
      #temperature { color: ${t.base0D}; }

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
        font-size: ${toString comfy.powerFont}px;
        padding: ${comfy.powerPad};
      }

      #hyprland-window {
        color: ${t.base04};
        font-weight: 600;
      }

      /* Submap (mode) indicator — bright pill so the active mode is obvious */
      #submap {
        color: ${t.base00};
        background-color: ${t.base0A};
        padding: ${comfy.submapPad};
        margin: 0 4px;
        border-radius: 10px;
        font-weight: 800;
      }
    ''
    + lib.optionalString (compactOutput != null) tightCss;

    settings =
      let
        mkBar = d: {
          layer = "top";
          position = "top";
          inherit (d) height spacing;
          margin-top = d.marginTop;
          margin-bottom = 0;
          margin-left = d.marginSide;
          margin-right = d.marginSide;

          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
            "tray"
            "network"
            "idle_inhibitor"
          ];
          modules-center = [
            "hyprland/submap"
            "custom/jalali"
            "clock"
            "custom/gregorian"
          ];
          modules-right =
            lib.optional hasBattery "battery"
            ++ lib.optional hasPowerProfiles "power-profiles-daemon"
            ++ [
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
            ];
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
            on-scroll-up = "hyprctl dispatch workspace m-1";
            on-scroll-down = "hyprctl dispatch workspace m+1";
            all-outputs = false;
          };

          "hyprland/window" = {
            max-length = d.windowLength;
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

          "custom/jalali" = {
            format = "{}";
            exec = "${pkgs.jcal}/bin/jdate +%Y/%b/%d";
            interval = 60;
            tooltip = false;
          };

          "custom/gregorian" = {
            format = "{}";
            exec = "${pkgs.coreutils}/bin/date +%Y/%^b/%d";
            interval = 60;
            tooltip = false;
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

          temperature = cpuTemperature // {
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

          "power-profiles-daemon" = {
            format = "{icon}";
            tooltip-format = "Power profile: {profile}\nDriver: {driver}\nClick to switch";
            format-icons = {
              default = "";
              performance = "󰽍";
              balanced = "󰍞";
              "power-saver" = "󰑱";
            };
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
            icon-size = d.trayIcon;
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
      in
      {
        mainBar =
          mkBar comfy
          // lib.optionalAttrs (compactOutput != null) {
            output = "!${compactOutput}";
          };
      }
      // lib.optionalAttrs (compactOutput != null) {
        compactBar = mkBar tight // {
          name = "waybar-compact";
          output = compactOutput;
        };
      };
  };
}
