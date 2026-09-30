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

      # Open zellij's session manager (welcome screen) instead of blindly
      # starting a new session. This used to run a zj-attach wrapper that
      # hunted for a session no other window was attached to and asked
      # "start a new one? [Y/n]" when it found none; the prompt was the first
      # thing every terminal showed, so the wrapper is gone. `--layout welcome`
      # is the builtin `zellij:session-manager` plugin with welcome_screen=true
      # (see zelij.nix), listing existing sessions with an option to create a
      # new one; session_serialization is off for this layout only, so
      # skipping the picker never leaves a garbage session behind.
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

      # Declared in home/modules/keys/registry.nix, so `keys ghostty` lists
      # them alongside every other shortcut on the machine.
      keybind = [ "clear" ] ++ config.custom.keys.rendered.ghostty;
    };
  };
}
