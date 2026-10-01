{ config, pkgs, ... }:
let
  dpms =
    action:
    pkgs.writeShellScript "dpms-${action}" ''
      exec hyprctl dispatch 'hl.dsp.dpms({ action = "${action}" })'
    '';
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "${dpms "on"}";
        ignore_dbus_inhibit = false;
        lock_cmd = config.custom.keys.commands.lockScreen or "pidof hyprlock || hyprlock";
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 500;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600;
          on-timeout = "${dpms "off"}";
          on-resume = "${dpms "on"}";
        }
        {
          timeout = 1200;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
