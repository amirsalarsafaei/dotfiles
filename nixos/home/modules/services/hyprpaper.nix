{ pkgs, ... }:

{
  # Ensure swww is installed
  home.packages = [ pkgs.swww ];

  # Create the workspace wallpaper script with embedded swww settings
  home.file.".config/hypr/scripts/workspace-wallpaper.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      ${pkgs.swww}/bin/swww query || ${pkgs.swww}/bin/swww-daemon &
      
      ${pkgs.swww}/bin/swww img ~/Pictures/Wallpaper.gif
    '';
  };

  # Add a systemd service to start the wallpaper script on login
  systemd.user.services.swww-wallpaper = {
    Unit = {
      Description = "Set workspace-specific wallpapers using swww";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ~/.config/hypr/scripts/workspace-wallpaper.sh";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
