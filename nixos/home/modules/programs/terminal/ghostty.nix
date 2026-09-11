{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Shaders shipped in this repo. Add a file under ./shaders/ and a line here.
  localShaders = {
    crt = ./shaders/crt.glsl;
    bloom = ./shaders/bloom.glsl;
    cursor_smear = ./shaders/cursor_smear.glsl;
    animated_gradient = ./shaders/animated_gradient.glsl;
    cineShader-Lava = ./shaders/cineShader-Lava.glsl;
    lava = ./shaders/lava.glsl;
    water = ./shaders/water.glsl;
    pacman = ./shaders/pacman-neo.glsl;
  };

  # These fun ones come from https://github.com/0xhckr/ghostty-shaders
  # callPackage wraps the returned attrset in makeOverridable, which injects
  # an extra "override" (function) attr alongside the real shader
  # derivations — filter it out or it ends up as a fake shader.
  remoteShaders = lib.filterAttrs (
    _: v: lib.isDerivation v
  ) (pkgs.callPackage ../../../../pkgs/ghostty-shaders.nix { });

  allShaders = localShaders // remoteShaders;
  shaderNames = lib.attrNames allShaders;
  knownShaders = lib.concatStringsSep "\n" shaderNames;

  selectShaderScript = pkgs.writeShellApplication {
    name = "select-ghostty-shader";
    runtimeInputs = [
      pkgs.rofi
      pkgs.gnused
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
      shader_config="$config_dir/shaders.conf"

      # Menu rows: "none" plus every installed shader.
      mapfile -t options < <(printf 'none\n%s\n' '${knownShaders}')

      # Which shader is live right now? (defaults to none)
      current=none
      if [[ -s "$shader_config" ]]; then
        current=$(sed -n 's#^custom-shader = shaders/\(.*\)\.glsl#\1#p' "$shader_config" | head -n1)
        [[ -z "$current" ]] && current=none
      fi

      # Highlight the active row in rofi (-a takes a 0-based row index).
      active=0
      for i in "''${!options[@]}"; do
        [[ "''${options[i]}" == "$current" ]] && { active=$i; break; }
      done

      choice=$(
        printf '%s\n' "''${options[@]}" \
          | rofi -dmenu -i -no-custom -a "$active" -p "  ghostty shader"
      ) || exit 0

      mkdir -p "$config_dir"
      if [[ "$choice" == none ]]; then
        : > "$shader_config"
      else
        printf 'custom-shader = shaders/%s.glsl\n' "$choice" > "$shader_config"
      fi

      # Live-apply to every running Ghostty (it reloads config on SIGUSR2).
      pkill -USR2 ghostty 2>/dev/null || true
    '';
  };

in
{
  # Make the picker available as a terminal command (and for the Hyprland bind).
  home.packages = [ selectShaderScript ];

  # Install every known shader next to the generated ghostty config so the
  # relative custom-shader paths (shaders/*.glsl) resolve.
  xdg.configFile = lib.mapAttrs' (
    name: src: lib.nameValuePair "ghostty/shaders/${name}.glsl" { source = src; }
  ) allShaders;

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      term = "xterm-256color";

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

      # Default shader config — the toggle script will modify this at runtime.
      custom-shader-animation = "true";
      # Relative path: Ghostty resolves config-file includes against the config
      # dir (~/.config/ghostty). It does NOT expand $HOME — an absolute-looking
      # "$HOME/..." gets treated as relative and silently fails the optional (?)
      # include, so the shader picker's file never loads.
      config-file = "?shaders.conf";
      confirm-close-surface = false;

      # Declared in home/modules/keys/registry.nix, so `keys ghostty` lists
      # them alongside every other shortcut on the machine.
      keybind = config.custom.keys.rendered.ghostty;
    };
  };
}
