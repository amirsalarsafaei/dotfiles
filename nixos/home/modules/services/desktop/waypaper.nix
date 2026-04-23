{ pkgs, lib, ... }:

{
  # Waypaper for efficient wallpaper management
  home.packages = [
    pkgs.waypaper
  ];

  # Create waypaper config directory
  home.file.".config/waypaper/config.ini" = {
    text = ''
      [Settings]
      ; Wallpaper backend: swaybg, hyprpaper, or swww
      backend = swww
      
      ; Image sorting: name, date, size, random
      image_sorter = name
      
      ; Show hidden files
      show_hidden_files = false
      
      ; Folder path (set to your wallpapers folder)
      folder = ''${config.home.homeDirectory}/Pictures/wallpapers
      
      ; Swallowing on launch - minimize after setting wallpaper
      swallow = false
      
      ; Fill window with app
      fill_option = center
      
      ; Default fill mode: fill, fit, stretch, tile, center, span
      default_fill = center
      
      ; Restore previous wallpaper on startup
      restore_previous_on_startup = true
      
      ; Monitors (for multi-monitor setups)
      ; monitors = all
      
      ; Low battery mode - optimize for battery life
      ; Uses swaybg instead of swww when battery < 20%
      battery_mode = true
      battery_threshold = 20
    '';
  };

  # Optional: Create systemd service for startup restoration (lightweight)
  systemd.user.services.waypaper-restore = {
    Unit = {
      Description = "Restore wallpaper on startup";
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.waypaper} restore";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
