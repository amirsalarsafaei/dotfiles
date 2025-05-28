{ pkgs, ... }:

{
  # Install waypaper and swww for GIF support
  home.packages = [ 
    pkgs.waypaper
    pkgs.swww
  ];

  # Create the workspace wallpaper script
  home.file.".config/hypr/scripts/workspace-wallpaper.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      
      # Wait for Hyprland to start properly
      sleep 1
      
      # Start swww daemon if not running
      ${pkgs.swww}/bin/swww query || ${pkgs.swww}/bin/swww init
      
      # Restore wallpaper using waypaper
      ${pkgs.waypaper}/bin/waypaper --restore
    '';
  };

  # Add a systemd service to start the wallpaper script after Hyprland starts
  systemd.user.services.wallpaper-service = {
    Unit = {
      Description = "Set wallpaper using waypaper with swww for GIF support";
      # Make sure this runs after the Hyprland session has started
      PartOf = ["hyprland-session.target"];
      After = ["hyprland-session.target"];
    };
    Service = {
      Type = "oneshot";
      # Use absolute path to the script
      ExecStart = "%h/.config/hypr/scripts/workspace-wallpaper.sh";
      # Environment variables needed for display access
      Environment = "WAYLAND_DISPLAY=wayland-1";
    };
    Install = {
      WantedBy = ["hyprland-session.target"];
    };
  };
}
