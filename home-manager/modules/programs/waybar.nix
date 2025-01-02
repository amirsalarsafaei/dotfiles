{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar =
        {
          layer = "top";
          exclusive = true;
          battery = {
            format = " \t{capacity}%";
            format-charging = "󰢝 \t{capacity}%";
            format-plugged = " \t{capacity}%";
            interval = 30;
          };
          clock = {
            format = "{:%H:%M:%S}";
            interval = 1;
          };
          cpu = {
            format = " \t{usage}%";
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
            format = " \t{}%";
            interval = 5;
          };
          "hyprland/window" = {
            format = "{}";
            max-length = 30;
          };
          modules-center = [ ];
          modules-left = [ "hyprland/workspaces" "tray" "network" "hyprland/window" ];
          modules-right = [ "temperature" "cpu" "memory" "wireplumber" "battery" "hyprland/language" "clock" ];
          network = {
            format = "Net via {ifname}";
            format-disconnected = "No net";
            format-wifi = "{essid} ({signalStrength}%)  ";
            tooltip-format = "{ipaddr}/{cidr}";
          };
          position = "top";
          temperature = {
            format = "\t{temperatureC}°C";
            interval = 1;
          };
          tray = {
            spacing = 10;
          };
          wireplumber = {
            format = " \t{volume}%";
            format-muted = "\tmute";
            on-click = "pavucontrol";
            scroll-step = 1;
          };
        };

    };
  };
}
