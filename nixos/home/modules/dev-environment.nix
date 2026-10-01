{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  devLibs = with pkgs; [
    openssl_3
    zlib
  ];
in
{
  nix.registry.dev.flake = inputs.self;

  home = {
    packages = map (p: p.dev) devLibs;

    sessionVariables = {
      PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" (map (p: p.dev) devLibs);
    };

    file.".config/clangd/config.yaml".text = ''
      CompileFlags:
        Add:
          - "-I${pkgs.glibc.dev}/include"
          - "-I${pkgs.gcc}/include"
        Compiler: ${pkgs.gcc}/bin/gcc
    '';
  };
}
