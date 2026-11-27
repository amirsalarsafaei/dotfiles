{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  devOutputs = map lib.getDev [
    pkgs.openssl
    pkgs.zlib
  ];
in
{
  nix.registry.dev.flake = inputs.self;

  home = {
    packages = devOutputs;

    sessionVariables = {
      GOPATH = "${config.home.homeDirectory}/go";
      GOBIN = "${config.home.homeDirectory}/.local/bin";
      PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" devOutputs;
    };

    file.".config/clangd/config.yaml".text = ''
      CompileFlags:
        Add:
          - "-I${pkgs.glibc.dev}/include"
          - "-I${pkgs.gcc}/include"
        Compiler: ${lib.getExe' pkgs.gcc "gcc"}
    '';
  };

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
}
