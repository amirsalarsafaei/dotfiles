{ config, homeDir, currentHostname, ... }:
{

  home.username = "amirsalar";
  home.homeDirectory = homeDir;

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
      .wakatime-project
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${homeDir}/go";
    GOPRIVATE = "git.divar.cloud";
    GOBIN = "${homeDir}/.local/bin";
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
    "yamllint/config".text = ''
      extends: relaxed
    '';
  };

  imports = [ ./modules ];
}
