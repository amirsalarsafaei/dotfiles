{
  inputs,
  nixpkgs,
  system,
  commonNixpkgsConfig,
}:
let
  pkgs = import nixpkgs ({ inherit system; } // commonNixpkgsConfig system);
  zellijExtraPlugins = pkgs.callPackage ../pkgs/zellij-plugins.nix { };
  neovimPlugins = pkgs.callPackage ../pkgs/neovim-plugins.nix { };
  tmuxExtraPlugins = pkgs.callPackage ../pkgs/tmux-plugins.nix { };
  obsidianGitAssets = pkgs.callPackage ../pkgs/obsidian-git-assets.nix { };
  ghosttyShaders = pkgs.callPackage ../pkgs/ghostty-shaders.nix { };
  geoData = pkgs.callPackage ../pkgs/geo-data.nix { };
in
{
  devar = pkgs.callPackage ../pkgs/devar.nix { devarSrc = inputs.devar; };
  chrome-devtools-mcp = pkgs.callPackage ../pkgs/chrome-devtools-mcp.nix { };
  zellij-harpoon = zellijExtraPlugins.harpoon;
  zellij-tabula = zellijExtraPlugins.tabula;
  zellaude = (pkgs.callPackage ../pkgs/zellaude.nix { }).unwrapped;
  nvim-base64 = neovimPlugins.base64Plugin;
  nvim-platformio-lua = neovimPlugins.platformioPlugin;
  tmux-battery = tmuxExtraPlugins.battery;
  obsidian-git-mainjs = obsidianGitAssets.mainJs;
  obsidian-git-manifest = obsidianGitAssets.manifestJson;
  obsidian-git-styles = obsidianGitAssets.stylesCss;
  ghostty-shader-inside-the-matrix = ghosttyShaders.inside-the-matrix;
  ghostty-shader-galaxy = ghosttyShaders.galaxy;
  ghostty-shader-just-snow = ghosttyShaders.just-snow;
  ghostty-shader-fireworks = ghosttyShaders.fireworks;
  ghostty-shader-underwater = ghosttyShaders.underwater;
  ghostty-shader-glitchy = ghosttyShaders.glitchy;
  ghostty-shader-starfield = ghosttyShaders.starfield;
  iran-geoip = geoData.geoip;
  iran-geosite = geoData.geosite;
}
