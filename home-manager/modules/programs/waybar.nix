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
          modules-left = [ "hyprland/workspaces" "hyprland/submap" "tray" "network" "hyprland/window" ];
          modules-right = [ "temperature" "cpu" "memory" "wireplumber" "battery" "hyprland/language" "clock" ];
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
        };

    };
  };
}
