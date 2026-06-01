{ config, lib, ... }:
let
  isNormal = config.custom.powerProfile == "normal";
in
{
  services.swaync = {
    enable = isNormal;
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
