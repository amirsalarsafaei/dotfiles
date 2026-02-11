{
  config,
  homeDir ? null,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Remove the hardcoded username - let it be set by the caller
  # home.username is automatically set by home-manager based on the user key

  # Use mkDefault to allow override, and handle homeDir properly
  home.homeDirectory = lib.mkDefault (
    if homeDir != null then homeDir else "/home/${config.home.username}"
  );

  home.stateVersion = "24.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".gitconfig-work".text = ''
            [user]
      					name = "Amirsalar Safaei"
      					email = "amirsalar.safaei@divar.ir"
            [core]
                excludesFile = "${config.home.homeDirectory}/.gitignore-work"
    '';
    ".gitignore-work".text = ''
      shell.nix
      .wakatime-project
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${config.home.homeDirectory}/go";
    GOPRIVATE = "git.divar.cloud";
    GOBIN = "${config.home.homeDirectory}/.local/bin";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  xdg.configFile = {
    "tmuxinator" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/personal/dotfiles/tmuxinator";
      recursive = true;
    };
    "nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/personal/dotfiles/nvim";
      recursive = true;
    };
    "yamllint/config".text = ''
      extends: relaxed
    '';
    "yamlfmt/.yamlfmt".text = ''
      formatter:
        type: basic
        retain_line_breaks: true
        drop_merge_tag: true
    '';
  };

  xdg = {
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          default = [ "hyprland" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
        hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.OpenURI" = [ "hyprland" ];
        };
      };
    };
    enable = true;
    mimeApps = {
      enable = false;
      defaultApplications = {
        "text/html" = [ "chromium.desktop" ];
        "x-scheme-handler/http" = [ "chromium.desktop" ];
        "x-scheme-handler/https" = [ "chromium.desktop" ];
      };
    };
  };

  sops = {
    secrets.ssh_config = {
      path = "${config.home.homeDirectory}/.ssh/config";
    };
  };

  imports = [
    ./modules
  ];

}
