{ config, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      term = "xterm-256color";
      background = config.custom.theme.resolved.surfaces.ink;

      shell-integration-features = "no-cursor,no-sudo,no-title";
      clipboard-read = "allow";
      clipboard-write = "allow";

      command = "zellij --layout welcome";

      window-decoration = false;
      window-padding-x = 8;
      window-padding-y = 8;
      resize-overlay = "never";

      unfocused-split-opacity = 0.9;

      cursor-style = "block";
      cursor-style-blink = false;
      cursor-color = config.custom.theme.resolved.colors.base04;
      cursor-text = config.custom.theme.resolved.surfaces.ink;
      custom-shader = "${./shaders/cursor_smear.glsl}";
      custom-shader-animation = "true";

      confirm-close-surface = false;

      keybind = [ "clear" ] ++ config.custom.keys.rendered.ghostty;
    };
  };
}
