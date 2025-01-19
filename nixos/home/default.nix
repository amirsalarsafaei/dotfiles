{ pkgs, config, homeDir, currentHostname, ... }:
let
  hostConfig = ./hosts + "/${currentHostname}.nix";
in
{

  home.username = "amirsalar";
  home.homeDirectory = "/home/amirsalar";

  home.stateVersion = "24.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # enviroent.

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".gitconfig-work".text = ''
            [user]
      					name = "Amirsalar Safaei"
      					email = "amirsalar.safaei@divar.ir"
            [core]
                excludesFile = "${homeDir}/.gitignore-work"
    '';
    ".gitignore-work".text = ''
      shell.nix
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${homeDir}/go";
    GOPRIVATE = "git.divar.cloud";
    GOBIN = "${homeDir}/.local/bin";
    PATH = "$PATH:/usr/local/bin";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  xdg.configFile = {
    "tmuxinator" = {
      source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/personal/dotfiles/tmuxinator";
      recursive = true;
    };
    "nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/personal/dotfiles/nvim";
      recursive = true;
    };
  };

  imports = [ ./modules hostConfig ];
}
