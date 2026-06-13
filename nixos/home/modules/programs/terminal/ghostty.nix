{ pkgs, lib, ... }:
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

  # Shaders fetched from the internet at build time. Add an entry with a url +
  # sha256, then enable it by name below. Get the hash with:
  #   nix-prefetch-url <url>
  # These fun ones come from https://github.com/0xhckr/ghostty-shaders
  fetchShader =
    name: sha256:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/0xhckr/ghostty-shaders/main/${name}.glsl";
      inherit sha256;
    };
  remoteShaders = {
    inside-the-matrix = fetchShader "inside-the-matrix" "0cdximbq8h3pscdmlcnylcph0yii6fvnp3cj2fx1266xvildy8ib"; # green Matrix rain
    galaxy = fetchShader "galaxy" "185n5wgav66a3w32xs4jmps9bgib3pc13lnzc6c06ms5apn158bg"; # swirling galaxy
    just-snow = fetchShader "just-snow" "1g8pk2pagsg5hrqyhfpfs81qqflnkwdm3qfgr5fns12ylnxlh88z"; # falling snow
    fireworks = fetchShader "fireworks" "17sjk8zfx62a0djfjyd1yj76n16rxqra45ckqlhfya4l9plwx8bf"; # fireworks bursts
    underwater = fetchShader "underwater" "1l5bhh6i7sir6dwn73f1rzs29a0zca1ny4nsm5s6aipyq5xqivph"; # underwater caustics
    glitchy = fetchShader "glitchy" "0g6i3wkys2cl33r1jyypqyw4n8033i6p5w3m9l2nxs6dz1smk5m3"; # glitch / RGB split
    starfield = fetchShader "starfield" "1hvdjbnaa8lx24x5065x059pnq60d77kyf0pv0bzra7bvq4pgnsi"; # flying through stars
  };

  allShaders = localShaders // remoteShaders;
  shaderNames = lib.attrNames allShaders;
  knownShaders = lib.concatStringsSep "\n" shaderNames;

  # Shader picker, packaged as a real command (`select-ghostty-shader`) on PATH
  # so it can be invoked from a terminal as well as from the Hyprland keybind.
  # The rofi menu highlights the currently-active shader, and selecting one
  # live-applies it by sending running Ghostty instances SIGUSR2 (reload).
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

      command = "tmux new-session";

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

      keybind = [
        "ctrl+shift+equal=increase_font_size:1"
        "ctrl+shift+minus=decrease_font_size:1"
        "ctrl+equal=reset_font_size"
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+r=reload_config"
      ];
    };
  };
}
