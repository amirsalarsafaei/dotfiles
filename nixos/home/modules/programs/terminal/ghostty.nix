{ pkgs, lib, ... }:
let
  # Shaders shipped in this repo. Add a file under ./shaders/ and a line here.
  localShaders = {
    crt = ./shaders/crt.glsl;
    bloom = ./shaders/bloom.glsl;
    cursor_smear = ./shaders/cursor_smear.glsl;
    animated_gradient = ./shaders/animated_gradient.glsl;
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
    lava = fetchShader "cineShader-Lava" "0p9lhilhc7j5rwkdkhp1xr37cvhbn1x8kdspqa6byhmxsmhwsxnp"; # molten lava
    fireworks = fetchShader "fireworks" "17sjk8zfx62a0djfjyd1yj76n16rxqra45ckqlhfya4l9plwx8bf"; # fireworks bursts
    underwater = fetchShader "underwater" "1l5bhh6i7sir6dwn73f1rzs29a0zca1ny4nsm5s6aipyq5xqivph"; # underwater caustics
    glitchy = fetchShader "glitchy" "0g6i3wkys2cl33r1jyypqyw4n8033i6p5w3m9l2nxs6dz1smk5m3"; # glitch / RGB split
    starfield = fetchShader "starfield" "1hvdjbnaa8lx24x5065x059pnq60d77kyf0pv0bzra7bvq4pgnsi"; # flying through stars
  };

  allShaders = localShaders // remoteShaders;

  # Turn shaders on/off here. Empty list = all off (no shader applied).
  # Ghostty stacks every enabled entry in the listed order, e.g.
  #   enabledShaders = [ "crt" "bloom" ];
  # Each name must exist in localShaders or remoteShaders above. Available
  # internet ones: inside-the-matrix, galaxy, just-snow, lava, fireworks,
  # underwater, glitchy, starfield.
  enabledShaders = [ ];
in
{
  # Install every known shader next to the generated ghostty config so the
  # relative custom-shader paths (shaders/*.glsl) resolve. Toggling a shader
  # then only needs an edit to enabledShaders above plus ctrl+shift+r.
  xdg.configFile = lib.mapAttrs' (
    name: src: lib.nameValuePair "ghostty/shaders/${name}.glsl" { source = src; }
  ) allShaders;

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    clearDefaultKeybinds = true;
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

      # Enabled shaders, derived from enabledShaders above. Edit that list and
      # hit ctrl+shift+r (reload_config) to apply without restarting.
      custom-shader = map (name: "shaders/${name}.glsl") enabledShaders;
      # Only animate the shader when something on screen is moving, to save GPU.
      custom-shader-animation = "true";

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
