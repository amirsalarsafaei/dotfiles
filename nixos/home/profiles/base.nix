{ config, lib, ... }:
{
  imports = [
    ../modules/personal.nix
    ../modules/power-profile.nix
    ../modules/keys
  ];

  home = {
    homeDirectory = lib.mkDefault "/home/${config.home.username}";

    stateVersion = "24.11";

    sessionVariables = {
      GOPATH = "${config.home.homeDirectory}/go";
      GOPRIVATE = "git.divar.cloud";
      GOBIN = "${config.home.homeDirectory}/.local/bin";
    };

    sessionPath = [
      "$HOME/.local/bin"
    ];
  };

  manual.manpages.enable = lib.mkDefault false;

  xdg = {
    enable = true;

    configFile = {
      "tmuxinator" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/personal/dotfiles/tmuxinator";
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
  };
}
