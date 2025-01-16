{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = false;
        hide_cursor = true;
        grace = 2;
        no_fade_in = false;
      };

      background = {
        monitor = "";
        path = "~/Pictures/lockscreen.png";
        blur_passes = 2;
        blur_size = 7;
        noise = 0.0117;
        contrast = 0.8917;
        brightness = 0.8172;
      };

      input-field = {
        monitor = "";
        size = {
          width = 200;
          height = 50;
        };
        outline_thickness = 3;
        dots_size = 0.33;
        dots_spacing = 0.15;
        dots_center = true;
        outer_color = "rgb(24, 25, 38)";
        inner_color = "rgb(91, 96, 120)";
        font_color = "rgb(202, 211, 245)";
        fade_on_empty = true;
        placeholder_text = "Password..."; # Removed placeholder text
        hide_input = false;
        position = {
          x = 0;
          y = 0; # Centered vertically
        };
        halign = "center";
        valign = "center";
      };

      # Time label
      label = {
        monitor = "";
        text = "$TIME";
        color = "rgb(202, 211, 245)";
        font_size = 64; # Larger time display
        font_family = "JetBrains Mono Nerd Font";
        position = {
          x = 0;
          y = -200; # Moved above the input field
        };
        halign = "center";
        valign = "center";
      };

      # Keyboard layout label
      label_kb_layout = {
        monitor = "";
        text = "󰌌  $KB_LAYOUT"; # Added keyboard icon
        color = "rgb(202, 211, 245)";
        font_size = 16;
        font_family = "JetBrains Mono Nerd Font";
        position = {
          x = 0;
          y = 50; # Below the input field
        };
        halign = "center";
        valign = "center";
      };
    };
  };
}
