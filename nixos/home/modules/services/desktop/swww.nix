{ pkgs, lib, ... }:

{
  # Install waypaper and swww for GIF support
  home.packages = [ 
    pkgs.waypaper
    pkgs.swww
  ];

  systemd.user.services.swww = {
    Unit = {
      Description = "swww wallpaper daemon";
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe' pkgs.swww "swww-daemon"}";
      Restart = "on-failure";
      StandardOutput = "null";
      StandardError = "null";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
