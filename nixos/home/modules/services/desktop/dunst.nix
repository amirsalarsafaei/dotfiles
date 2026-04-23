{ config, ... }:
let
  t = config.theme;
in
{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        # ── Layout ──────────────────────────────────────────────
        origin            = "top-right";
        offset            = "16x20";
        width             = "(280, 420)";
        height            = 200;
        notification_limit = 5;
        gap_size          = 8;

        # ── Appearance ──────────────────────────────────────────
        corner_radius        = 16;
        frame_width          = 1;
        frame_color          = "${t.glassBorder}99";
        separator_color      = "frame";
        separator_height     = 1;
        padding              = 14;
        horizontal_padding   = 16;
        text_icon_padding    = 12;

        # ── Typography ──────────────────────────────────────────
        font             = "JetBrainsMono Nerd Font 11";
        markup           = "full";
        format           = "<b>%s</b>\\n<span size='small'>%b</span>";
        alignment        = "left";
        vertical_alignment = "center";
        word_wrap        = true;
        ellipsize        = "end";
        ignore_newline   = false;
        line_height      = 2;

        # ── Icons ───────────────────────────────────────────────
        icon_theme                   = "Papirus-Dark";
        enable_recursive_icon_lookup = true;
        icon_position                = "left";
        min_icon_size                = 32;
        max_icon_size                = 48;

        # ── Progress bar ────────────────────────────────────────
        progress_bar               = true;
        progress_bar_height        = 6;
        progress_bar_frame_width   = 0;
        progress_bar_min_width     = 180;
        progress_bar_max_width     = 360;
        progress_bar_corner_radius = 6;
        highlight                  = t.accent;

        # ── Behaviour ───────────────────────────────────────────
        sort              = "yes";
        indicate_hidden   = "yes";
        show_age_threshold = 60;
        sticky_history    = "yes";
        history_length    = 20;
        always_run_script = true;
        hide_duplicate_count = false;
        show_indicators   = "yes";

        # ── Mouse ───────────────────────────────────────────────
        mouse_left_click   = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click  = "close_all";
      };

      urgency_low = {
        background  = "${t.glass}cc";
        foreground  = t.subtle;
        frame_color = "${t.surface}99";
        timeout     = 6;
      };

      urgency_normal = {
        background  = "${t.glassStrong}e6";
        foreground  = t.fg;
        frame_color = "${t.glassBorder}cc";
        timeout     = 8;
      };

      urgency_critical = {
        background  = "${t.bg}f2";
        foreground  = t.fgBright;
        frame_color = t.urgent;
        highlight   = t.urgent;
        timeout     = 0;
      };
    };
  };
}
