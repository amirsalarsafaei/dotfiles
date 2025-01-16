{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        padding = 5;
        corner_radius = 10;
        frame_color = "#eceff1";
        font = "JetBrainsMono Nerd Font Mono";
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 1;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;
        progress_bar_corner_radius = 5;
        highlight = "#34a1db";
      };

      urgency_normal = {
        background = "#5f7296";
        foreground = "#eceff1";
        timeout = 10;
      };
    };
  };
}
