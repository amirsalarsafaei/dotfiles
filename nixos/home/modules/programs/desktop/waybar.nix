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
  s = config.custom.theme.resolved.surfaces;
  a = config.custom.theme.resolved.accents;
  value = text: "<span color='${t.base05}'>${text}</span>";
  lyrics = config.custom.lyrics;

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
    spacing = 4;
    marginTop = 6;
    marginSide = 12;
    barRadius = 14;
    edge = 5;
    pad = "3px 8px";
    buttonPad = "2px 9px";
    powerFont = 16;
    powerPad = "4px 12px";
    trayIcon = 18;
    clockPad = "3px 10px";
    groupPad = "2px 5px";
    itemPad = "2px 9px";
    submapPad = "4px 16px";
    windowLength = 36;
    lyricsLength = 48;
    gap = "  ";
    networkLabel = true;
  };

  tight = {
    fontSize = 11;
    height = 28;
    spacing = 2;
    marginTop = 4;
    marginSide = 6;
    barRadius = 11;
    edge = 3;
    pad = "2px 7px";
    buttonPad = "1px 7px";
    powerFont = 14;
    powerPad = "2px 10px";
    trayIcon = 16;
    clockPad = "2px 9px";
    groupPad = "1px 4px";
    itemPad = "1px 7px";
    submapPad = "2px 12px";
    windowLength = 28;
    lyricsLength = 28;
    gap = " ";
    networkLabel = false;
  };

  tightCss = ''
    window#waybar.waybar-compact,
    window#waybar.waybar-compact * {
      font-size: ${toString tight.fontSize}px;
    }
    window#waybar.waybar-compact .modules-left,
    window#waybar.waybar-compact .modules-center,
    window#waybar.waybar-compact .modules-right {
      border-radius: ${toString tight.barRadius}px;
      padding: 0 ${toString tight.edge}px;
    }
    window#waybar.waybar-compact #workspaces,
    window#waybar.waybar-compact #idle_inhibitor,
    window#waybar.waybar-compact #clock,
    window#waybar.waybar-compact #custom-jalali,
    window#waybar.waybar-compact #custom-gregorian,
    window#waybar.waybar-compact #custom-agenda,
    window#waybar.waybar-compact #network,
    window#waybar.waybar-compact #wireplumber,
    window#waybar.waybar-compact #tray,
    window#waybar.waybar-compact #hyprland-language,
    window#waybar.waybar-compact #power-profiles-daemon,
    window#waybar.waybar-compact #battery,
    window#waybar.waybar-compact #hyprland-window,
    window#waybar.waybar-compact #custom-lyrics,
    window#waybar.waybar-compact #cava,
    window#waybar.waybar-compact #custom-sidebar,
    window#waybar.waybar-compact #custom-logout,
    window#waybar.waybar-compact #custom-reboot,
    window#waybar.waybar-compact #custom-shutdown {
      padding: ${tight.pad};
    }
    window#waybar.waybar-compact #workspaces { padding: 0 1px; }
    window#waybar.waybar-compact #workspaces button { padding: ${tight.buttonPad}; }
    window#waybar.waybar-compact #workspaces button.active { min-width: 22px; }
    window#waybar.waybar-compact #clock { padding: ${tight.clockPad}; }
    window#waybar.waybar-compact #hardware { padding: ${tight.groupPad}; }
    window#waybar.waybar-compact #cpu,
    window#waybar.waybar-compact #memory,
    window#waybar.waybar-compact #temperature {
      padding: ${tight.itemPad};
    }
    window#waybar.waybar-compact #custom-power,
    window#waybar.waybar-compact #custom-sidebar {
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

  custom.lyrics.widths = [
    comfy.lyricsLength
  ]
  ++ lib.optional (compactOutput != null) tight.lyricsLength;

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
        font-family: 'JetBrainsMono Nerd Font', 'Font Awesome 6 Free', monospace;
        font-size: ${toString comfy.fontSize}px;
        font-weight: 500;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      /* The bar window is transparent and floats clear of the screen edges
         (see mainBar margin below). The left, center and right module
         boxes each carry their own translucent background, so the bar
         reads as three rounded islands over the wallpaper. The compositor's
         layer rule blurs only that translucency (see the `waybar` layerrule
         in hyprland.nix), so the islands read as glass and the gaps between
         them stay clear. */
      window#waybar {
        background: transparent;
        color: ${t.base05};
      }

      /* Each module box is its own island; the padding keeps the outermost
         pills clear of the rounded border. */
      .modules-left,
      .modules-center,
      .modules-right {
        background: ${s.ink};
        border: 1px solid ${s.line};
        border-radius: ${toString comfy.barRadius}px;
        padding: 0 ${toString comfy.edge}px;
      }

      tooltip {
        background: ${themeLib.rgba s.ink 0.97};
        border: 1px solid ${s.line};
        border-radius: 10px;
      }
      tooltip label {
        color: ${t.base07};
      }

      menu {
        background: ${s.ink};
        border: 1px solid ${s.line};
        padding: 4px;
      }
      menu menuitem {
        color: ${t.base05};
        padding: 4px 10px;
      }
      menu menuitem:hover {
        background: ${themeLib.rgba a.primary 0.22};
        color: ${t.base07};
      }

      /* Shared pill geometry for every standalone module: identical padding
         keeps the hover highlights and the clock/group accents aligned. */
      #workspaces,
      #idle_inhibitor,
      #clock,
      #custom-jalali,
      #custom-gregorian,
      #custom-agenda,
      #network,
      #wireplumber,
      #tray,
      #hyprland-language,
      #power-profiles-daemon,
      #custom-power,
      #custom-logout,
      #custom-reboot,
      #custom-shutdown,
      #battery,
      #hyprland-window {
        background-color: transparent;
        color: ${t.base05};
        padding: ${comfy.pad};
        margin: 3px 1px;
        border-radius: 9px;
        transition: background-color 0.2s ease, color 0.2s ease, border-color 0.2s ease;
      }

      #custom-sidebar {
        color: ${a.primary};
        font-size: ${toString comfy.powerFont}px;
        padding: ${comfy.powerPad};
        margin: 3px 1px;
        border-radius: 9px;
      }

      #custom-sidebar:hover {
        background-color: ${themeLib.rgba t.base02 0.45};
        color: ${t.base07};
      }

      #workspaces {
        padding: 0 2px;
      }

      #workspaces button {
        padding: ${comfy.buttonPad};
        margin: 0 1px;
        background-color: transparent;
        color: ${t.base04};
        border-radius: 8px;
        min-width: 14px;
        transition: all 0.35s cubic-bezier(0.32, 0.85, 0.18, 1);
      }

      #workspaces button:hover {
        background: ${themeLib.rgba t.base02 0.55};
        color: ${t.base07};
      }

      #workspaces button.empty {
        color: ${t.base03};
      }

      #workspaces button.visible {
        background-color: ${themeLib.rgba a.primary 0.1};
        box-shadow: inset 0 0 0 1px ${themeLib.rgba a.primary 0.35};
        color: ${t.base07};
      }

      #workspaces button.active {
        background: ${themeLib.rgba a.primary 0.35};
        color: ${t.base07};
        font-weight: 600;
        min-width: 30px;
      }

      #workspaces button.urgent {
        background: ${themeLib.rgba t.base08 0.75};
        color: ${s.ink};
      }

      #idle_inhibitor { color: ${t.base03}; }
      #idle_inhibitor.activated {
        color: ${t.base0C};
        background-color: ${themeLib.rgba t.base0C 0.14};
      }

      /* Hover feedback is shared so no module reads as inert. A slight lift
         reads as "clickable" without needing a border on every pill. */
      #idle_inhibitor:hover,
      #clock:hover,
      #custom-agenda:hover,
      #network:hover,
      #wireplumber:hover,
      #hyprland-language:hover,
      #power-profiles-daemon:hover,
      #custom-power:hover,
      #battery:hover {
        background-color: ${themeLib.rgba t.base02 0.45};
      }

      #clock {
        font-weight: 600;
        color: ${a.primary};
        padding: ${comfy.clockPad};
        letter-spacing: 0.04em;
      }

      #cava {
        color: ${a.secondary};
        padding: ${comfy.pad};
        margin: 3px 1px;
      }

      #custom-jalali,
      #custom-gregorian {
        color: ${t.base04};
        font-weight: 400;
      }

      #custom-agenda { color: ${t.base04}; }
      #custom-agenda.later { color: ${a.secondary}; }
      #custom-agenda.upcoming { color: ${a.warm}; }
      #custom-agenda.soon {
        color: ${a.heat};
        background-color: ${themeLib.rgba a.heat 0.14};
      }
      #custom-agenda.now {
        color: ${t.base07};
        background-color: ${themeLib.rgba a.primary 0.3};
      }
      #custom-agenda.tasks { color: ${t.base05}; }
      #custom-agenda.overdue { color: ${a.warm}; }
      #custom-agenda.setup,
      #custom-agenda.stale { color: ${t.base04}; }

      #tray > .needs-attention {
        background-color: ${themeLib.rgba t.base08 0.25};
        border-radius: 8px;
      }

      /* Each module gets its own accent color so the right-hand cluster reads
         as distinct icons at a glance instead of one grey block of text. */
      #network              { color: ${t.base04}; }
      #network.disconnected { color: ${t.base08}; }

      #wireplumber          { color: ${t.base04}; }
      #wireplumber.muted    { color: ${t.base03}; }

      #hyprland-language { color: ${t.base04}; }

      #power-profiles-daemon.performance { color: ${a.heat}; }
      #power-profiles-daemon.balanced { color: ${t.base04}; }
      #power-profiles-daemon.power-saver { color: ${t.base04}; }

      /* CPU/memory/temperature read as one inset group. */
      #hardware {
        padding: ${comfy.groupPad};
        margin: 3px 1px;
      }

      #cpu, #memory, #temperature {
        padding: ${comfy.itemPad};
        border-radius: 7px;
      }

      #cpu,
      #memory,
      #temperature { color: ${t.base04}; }

      #temperature.critical,
      #battery.warning:not(.charging) {
        color: ${t.base0A};
      }

      #temperature.critical {
        background-color: ${themeLib.rgba t.base08 0.18};
        color: ${t.base08};
      }

      #battery.charging, #battery.plugged { color: ${a.primary}; }

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
        color: ${a.primary};
        font-size: ${toString comfy.powerFont}px;
        padding: ${comfy.powerPad};
      }

      #custom-power:hover {
        background-color: ${themeLib.rgba t.base08 0.16};
        color: ${t.base08};
      }

      .power-child {
        color: ${t.base04};
        font-size: ${toString comfy.powerFont}px;
      }
      #custom-logout:hover {
        background-color: ${themeLib.rgba a.warm 0.16};
        color: ${a.warm};
      }
      #custom-reboot:hover {
        background-color: ${themeLib.rgba a.secondary 0.16};
        color: ${a.secondary};
      }
      #custom-shutdown:hover {
        background-color: ${themeLib.rgba t.base08 0.16};
        color: ${t.base08};
      }

      #hyprland-window {
        color: ${t.base04};
        font-weight: 400;
      }

      #custom-lyrics {
        color: ${a.primary};
        font-style: italic;
        font-weight: 400;
        padding: ${comfy.pad};
        margin: 3px 1px;
        border-radius: 9px;
        transition: background-color 0.2s ease;
      }

      #custom-lyrics:hover {
        background-color: ${themeLib.rgba t.base02 0.45};
      }

      /* Submap (mode) indicator — bright pill so the active mode is obvious */
      #submap {
        color: ${s.ink};
        background: ${a.warm};
        padding: ${comfy.submapPad};
        margin: 3px 1px;
        border-radius: 9px;
        font-weight: 600;
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
            "custom/sidebar"
            "hyprland/workspaces"
            "hyprland/submap"
            "custom/agenda"
            "cava"
            "custom/lyrics"
          ];
          modules-center = [
            "custom/jalali"
            "clock"
            "custom/gregorian"
          ];
          modules-right = [
            "tray"
            "network"
            "idle_inhibitor"
          ]
          ++ lib.optional hasBattery "battery"
          ++ lib.optional hasPowerProfiles "power-profiles-daemon"
          ++ [
            "wireplumber"
            "group/hardware"
            "hyprland/language"
            "group/power"
          ];

          network = {
            interval = 2;
            format-wifi = "" + lib.optionalString d.networkLabel "  ${value "{essid}"}";
            format-ethernet = "󰈀" + lib.optionalString d.networkLabel "  ${value "LAN"}";
            tooltip-format-wifi = "{essid} ({signalStrength}%)\nIP: {ipaddr}\nDOWN: {bandwidthDownBytes} | UP: {bandwidthUpBytes}";
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
              default = "";
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
            on-click = config.custom.keys.commands.widgetsToggle;
            format = "󰅐 <span color='${t.base07}'>{:%H:%M}</span>";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              format = {
                months = "<span color='${t.base07}'><b>{}</b></span>";
                days = "<span color='${t.base05}'><b>{}</b></span>";
                weekdays = "<span color='${a.primary}'><b>{}</b></span>";
                today = "<span color='${t.base08}'><b><u>{}</u></b></span>";
              };
            };
          };

          cava = {
            framerate = 30;
            bars = 14;
            autosens = 1;
            lower_cutoff_freq = 50;
            higher_cutoff_freq = 10000;
            method = "pulse";
            source = "auto";
            stereo = true;
            bar_delimiter = 0;
            monstercat = true;
            noise_reduction = 0.8;
            input_delay = 2;
            sleep_timer = 3;
            hide_on_silence = true;
            format-icons = [
              "▁"
              "▂"
              "▃"
              "▄"
              "▅"
              "▆"
              "▇"
              "█"
            ];
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

          "custom/lyrics" = {
            exec = "${lib.getExe' pkgs.coreutils "cat"} \"$XDG_RUNTIME_DIR\"/${lib.escapeShellArg lyrics.stateDir}/line-${toString d.lyricsLength}.json";
            return-type = "json";
            signal = lyrics.waybarSignal;
            format = "󰎈 {}";
            hide-empty-text = true;
            escape = true;
            max-length = d.lyricsLength + 2;
            on-click = config.custom.keys.commands.sidebarToggle;
          };

          "custom/agenda" = {
            exec = "agenda-os waybar";
            return-type = "json";
            interval = 30;
            signal = 9;
            on-click = "agenda-os show";
            on-click-middle = "agenda-os done";
            on-click-right = "agenda-os connect";
            tooltip = true;
          };

          wireplumber = {
            format = "{icon}  ${value "{volume}%"}";
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
            format = "${d.gap}${value "{usage}%"}";
          };

          memory = {
            interval = 5;
            format = "${d.gap}${value "{percentage}%"}";
          };

          temperature = cpuTemperature // {
            critical-threshold = 80;
            format = "{icon} ${value "{temperatureC}°C"}";
            format-critical = "{icon} {temperatureC}°C";
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
              performance = "󱓞";
              balanced = "󰗑";
              "power-saver" = "󰌪";
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
              activated = "󰅶";
              deactivated = "󰛊";
            };
            tooltip-format-activated = "Idle inhibitor: ON";
            tooltip-format-deactivated = "Idle inhibitor: OFF";
          };

          tray = {
            icon-size = d.trayIcon;
            spacing = 4;
          };

          "group/power" = {
            orientation = "inherit";
            drawer = {
              transition-duration = 420;
              children-class = "power-child";
              transition-left-to-right = false;
            };
            modules = [
              "custom/power"
              "custom/logout"
              "custom/reboot"
              "custom/shutdown"
            ];
          };

          "custom/sidebar" = {
            format = "";
            tooltip-format = "Dashboard (Super+D)";
            on-click = config.custom.keys.commands.sidebarToggle;
          };

          "custom/logout" = {
            format = "󰍃";
            tooltip-format = "Double-click to log out";
            on-double-click = "uwsm stop";
          };

          "custom/reboot" = {
            format = "󰜉";
            tooltip-format = "Double-click to reboot";
            on-double-click = "systemctl reboot";
          };

          "custom/shutdown" = {
            format = "󰐥";
            tooltip-format = "Double-click to shut down";
            on-double-click = "systemctl poweroff";
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
