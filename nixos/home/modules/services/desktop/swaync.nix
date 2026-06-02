{ config, lib, ... }:
let
  isNormal = config.custom.powerProfile == "normal";
  t = config.custom.theme.resolved.colors;
in
{
  services.swaync = {
    enable = isNormal;

    style = ''
      * {
        font-family: "Inter";
        font-size: 12pt;
      }

      /* progress bars */
      progress, progressbar, trough {
        border-radius: 6px;
      }
      trough {
        background: ${t.base01};
        border: 1px solid ${t.base02};
      }
      progress { background: ${t.base0D}; }

      /* notification card — one element owns the border + radius, so there is
         no second misaligned frame and the urgency accent recolors that single
         border rather than adding another. */
      .notification {
        margin: 6px 8px;
        border: none;
        background: transparent;
        box-shadow: none;
      }
      .notification-row,
      .floating-notifications.background .notification-row .notification-background {
        background: transparent;
      }
      .notification-content {
        background: ${t.base00};
        border: 1px solid ${t.base02};
        border-radius: 8px;
        padding: 12px;
        color: ${t.base05};
      }

      /* urgency accent — recolors the single border, no extra frame */
      .notification.low .notification-content { border-color: ${t.base03}; }
      .notification.low progress { background: ${t.base03}; }
      .notification.normal .notification-content { border-color: ${t.base0D}; }
      .notification.normal progress { background: ${t.base0F}; }
      .notification.critical .notification-content { border-color: ${t.base08}; }
      .notification.critical progress { background: ${t.base08}; }

      .summary { color: ${t.base07}; font-weight: bold; }
      .body { color: ${t.base05}; }
      .time { color: ${t.base04}; }

      .notification-action {
        color: ${t.base05};
        background: ${t.base01};
        border: 1px solid ${t.base02};
        border-radius: 6px;
      }
      .notification-action:hover { background: ${t.base02}; }
      .notification-action:active { background: ${t.base0F}; }

      .close-button {
        color: ${t.base00};
        background: ${t.base08};
        border-radius: 6px;
        margin: 6px;
        padding: 2px;
      }
      .close-button:hover { background: ${t.base09}; }

      /* control center */
      .control-center {
        background: ${t.base00};
        border: 1px solid ${t.base02};
        border-radius: 12px;
        color: ${t.base05};
      }
      .control-center .notification-row .notification-background,
      .control-center .notification-row .notification-background:hover {
        background: ${t.base01};
        border-radius: 8px;
      }
      .control-center .notification-row .notification-content {
        border: none;
        background: transparent;
      }

      .widget-title { color: ${t.base05}; margin: 0.5rem; }
      .widget-title > button {
        background: ${t.base01};
        border: 1px solid ${t.base02};
        border-radius: 6px;
        color: ${t.base05};
      }
      .widget-title > button:hover { background: ${t.base02}; }

      .widget-dnd { color: ${t.base05}; margin: 0.5rem; }
      .widget-dnd > switch {
        background: ${t.base01};
        border: 1px solid ${t.base02};
        border-radius: 12px;
      }
      .widget-dnd > switch:checked { background: ${t.base0D}; }
      .widget-dnd > switch slider { background: ${t.base06}; border-radius: 12px; }

      .widget-mpris { color: ${t.base05}; }
      .widget-mpris .widget-mpris-player {
        background: ${t.base01};
        border: 1px solid ${t.base02};
        border-radius: 8px;
      }
      .widget-mpris .widget-mpris-player button:hover { background: ${t.base02}; }
    '';

    settings = {
      positionX = "right";
      positionY = "top";

      control-center-margin-top = 8;
      control-center-margin-bottom = 8;
      control-center-margin-right = 8;
      control-center-margin-left = 8;

      control-center-width = 440;
      control-center-height = 640;
      notification-window-width = 420;

      notification-icon-size = 48;
      notification-body-image-height = 120;
      notification-body-image-width = 220;

      timeout = 8;
      timeout-low = 6;
      timeout-critical = 0;

      fit-to-screen = true;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;

      widgets = [
        "title"
        "dnd"
        "mpris"
        "notifications"
      ];

      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        mpris = {
          image-size = 80;
          image-radius = 8;
        };
      };
    };
  };
}
