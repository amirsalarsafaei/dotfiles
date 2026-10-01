{ inputs, pkgs }:
let
  zellijExtraPlugins = pkgs.callPackage ../pkgs/zellij-plugins.nix { };
  neovimPlugins = pkgs.callPackage ../pkgs/neovim-plugins.nix { };
  tmuxExtraPlugins = pkgs.callPackage ../pkgs/tmux-plugins.nix { };
  obsidianGitAssets = pkgs.callPackage ../pkgs/obsidian-git-assets.nix { };
  obsidianHomepageAssets = pkgs.callPackage ../pkgs/obsidian-homepage-assets.nix { };
  geoData = pkgs.callPackage ../pkgs/geo-data.nix { };
in
{
  devar = pkgs.callPackage ../pkgs/devar.nix { devarSrc = inputs.devar; };
  chrome-devtools-mcp = pkgs.callPackage ../pkgs/chrome-devtools-mcp.nix { };
  agent360-browser-mcp = pkgs.callPackage ../pkgs/agent360-browser-mcp { };
  airpods-tui = pkgs.callPackage ../pkgs/airpods-tui.nix { };
  zellij-harpoon = zellijExtraPlugins.harpoon;
  zellij-tabula = zellijExtraPlugins.tabula;
  nvim-base64 = neovimPlugins.base64Plugin;
  nvim-platformio-lua = neovimPlugins.platformioPlugin;
  tmux-battery = tmuxExtraPlugins.battery;
  obsidian-git-mainjs = obsidianGitAssets.mainJs;
  obsidian-git-manifest = obsidianGitAssets.manifestJson;
  obsidian-git-styles = obsidianGitAssets.stylesCss;
  obsidian-homepage-mainjs = obsidianHomepageAssets.mainJs;
  obsidian-homepage-manifest = obsidianHomepageAssets.manifestJson;
  obsidian-homepage-styles = obsidianHomepageAssets.stylesCss;
  iran-geoip = geoData.geoip;
  iran-geosite = geoData.geosite;
}
