{ ... }:

{
  # Create waypaper configuration directory
  home.file.".config/waypaper/config.ini" = {
    text = ''
      [Settings]
      wallpaper = ~/Pictures/Wallpaper.gif
      backend = swww
      colorscheme = 
      monitors = All
      fill = Fill
      sort = name
      subfolders = true
      post_command = 
      language = en
      folders = ~/Pictures
      wallpaper_dir = ~/Pictures
      restore_wallpaper = true
      magnifier = true
      favorites = true
      filter = false
      max_tiles = 10
      min_tiles = 3
    '';
  };
}
