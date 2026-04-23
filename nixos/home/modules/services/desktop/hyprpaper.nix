{ pkgs, lib, ... }:

{
  # Install hyprpaper for wallpaper support
  home.packages = [ 
    pkgs.hyprpaper
  ];

  systemd.user.services.hyprpaper = {
    Unit = {
      Description = "hyprpaper wallpaper daemon";
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.hyprpaper}";
      Restart = "on-failure";
      StandardOutput = "null";
      StandardError = "null";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
