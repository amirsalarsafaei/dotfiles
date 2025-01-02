{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;

      preload =
        [ "~/Pictures/lockscreen.png" ];

      wallpaper = [
        ",~/Pictures/lockscreen.png"
      ];
    };

  };
}
