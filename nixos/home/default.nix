{
  config,
  homeDir ? null,
  lib,
  ...
}:
{

  home.homeDirectory = lib.mkDefault (
    if homeDir != null then homeDir else "/home/${config.home.username}"
  );

  home.stateVersion = "24.11"; # Please read the comment before changing.

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
    enable = true;
  };

  sops = {
    secrets.ssh_config = {
      path = "${config.home.homeDirectory}/.ssh/config.d/sops";
    };
  };

  custom.neovim.enable = true;

  imports = [
    ./modules
  ];

}
