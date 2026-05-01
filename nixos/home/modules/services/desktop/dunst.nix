{ config, ... }:
let
  t = config.custom.theme.resolved.colors;
in
{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "16x20";
        width = "(280, 420)";
        height = 200;
        notification_limit = 5;
        gap_size = 8;

        corner_radius = 16;
        frame_width = 1;
        frame_color = "${t.base03}99";
        separator_color = "frame";
        separator_height = 1;
        padding = 14;
        horizontal_padding = 16;
        text_icon_padding = 12;

        font = "Maple Mono NF 11";
        markup = "full";
        format = "<b>%s</b>\n<span size='small'>%b</span>";
        alignment = "left";
        vertical_alignment = "center";
        word_wrap = true;
        ellipsize = "end";
        ignore_newline = false;
        line_height = 2;

        icon_theme = "Papirus-Dark";
        enable_recursive_icon_lookup = true;
        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 48;

        progress_bar = true;
        progress_bar_height = 6;
        progress_bar_frame_width = 0;
        progress_bar_min_width = 180;
        progress_bar_max_width = 360;
        progress_bar_corner_radius = 6;
        highlight = t.base0D;

        sort = "yes";
        indicate_hidden = "yes";
        show_age_threshold = 60;
        sticky_history = "yes";
        history_length = 20;
        always_run_script = true;
        hide_duplicate_count = false;
        show_indicators = "yes";

        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      urgency_low = {
        background = "${t.base01}cc";
        foreground = t.base04;
        frame_color = "${t.base02}99";
        timeout = 6;
      };

      urgency_normal = {
        background = "${t.base00}e6";
        foreground = t.base05;
        frame_color = "${t.base03}cc";
        timeout = 8;
      };

      urgency_critical = {
        background = "${t.base00}f2";
        foreground = t.base07;
        frame_color = t.base08;
        highlight = t.base08;
        timeout = 0;
      };
    };
  };
}
