{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  devOutputs = map lib.getDev [
    pkgs.openssl_3
    pkgs.zlib
  ];
in
{
  nix.registry.dev.flake = inputs.self;

  home = {
    packages = devOutputs;

    sessionVariables = {
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
}
