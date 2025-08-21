{pkgs, ...}:
{
  programs.hyprlock = {
    enable = true;
    package = pkgs.stable.hyprlock;
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
        size = "200, 50";
        outline_thickness = 3;
        dots_size = 0.33;
        dots_spacing = 0.15;
        dots_center = true;
        outer_color = "rgb(24, 25, 38)";
        inner_color = "rgb(91, 96, 120)";
        font_color = "rgb(202, 211, 245)";
        capslock_color = "rgba(255,0,0,1)";
        fade_on_empty = true;
        placeholder_text = "Password...";
        hide_input = false;
        position = "0, 0";
        halign = "center";
        valign = "center";
      };

      # Time label

      # Keyboard layout label
      # label = {
      #   monitor = "";
      #   text = "󰌌  $LAYOUT"; # Added keyboard icon
      #   color = "rgb(202, 211, 245)";
      #   font_size = 16;
      #   font_family = "JetBrains Mono Nerd Font";
      #   position = {
      #     x = 80;
      #     y = 0; # Below the input field
      #   };
      #   halign = "center";
      #   valign = "center";
      # };
    };
    extraConfig = ''
      label {
          monitor = 
          text = Hi there, $USER
          color = rgba(200, 200, 200, 1.0)
          font_size = 25
          font_family = Noto Sans

          position = 0, 80
          halign = center
          valign = center
      }
      
      label {
          monitor = 
          text = $LAYOUT
          color = rgba(200, 200, 200, 1.0)
          font_size = 25
          font_family = Noto Sans

          position = 0, -180
          halign = center
          valign = center
      }

      label {
          monitor = 
          text = $TIME
          color = rgba(200, 200, 200, 1.0)
          font_size = 64
          font_family = Noto Sans

          position = 0, 300
          halign = center
          valign = center
      }
    '';
  };
}
