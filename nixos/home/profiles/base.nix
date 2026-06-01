{
  config,
  homeDir ? null,
  lib,
  ...
}:
{
  imports = [
    ../modules/power-profile.nix
  ];

  home.homeDirectory = lib.mkDefault (
    if homeDir != null then homeDir else "/home/${config.home.username}"
  );

  home.stateVersion = "24.11";

  home.sessionVariables = {
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
}
