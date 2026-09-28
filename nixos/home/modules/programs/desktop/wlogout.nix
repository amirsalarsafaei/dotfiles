{ config, pkgs, ... }:
let
  t = config.custom.theme.resolved.colors;
  s = config.custom.theme.resolved.surfaces;
  a = config.custom.theme.resolved.accents;
in
{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "loginctl lock-session";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "uwsm stop";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "s";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "p";
      }
    ];
    style = ''
      * {
        background-image: none;
        font-family: "Maple Mono NF", monospace;
        font-size: 18px;
        transition: 200ms cubic-bezier(0.25, 0.1, 0.25, 1);
      }

      window {
        background-color: ${s.ink}d9;
      }

      button {
        color: ${t.base05};
        background-color: ${s.raised}cc;
        border: 2px solid ${s.line};
        border-radius: 16px;
        margin: 14px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
      }

      button:focus, button:active, button:hover {
        background-color: ${a.primary}1f;
        border-color: ${a.primary};
        color: ${t.base07};
        outline-style: none;
      }
    '';
  };

  home.packages = [ pkgs.wlogout ];
}
