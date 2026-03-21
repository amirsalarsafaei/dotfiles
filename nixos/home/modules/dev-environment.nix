{ pkgs, lib, ... }:
let
  # Add dev libraries here as needed — both .dev outputs and PKG_CONFIG_PATH
  # are derived automatically from this single list
  devLibs = with pkgs; [
    openssl_3
    zlib
  ];
in
{
  home.packages = map (p: p.dev) devLibs;

  home.sessionVariables = {
    PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" (map (p: p.dev) devLibs);
  };
  home.file.".config/clangd/config.yaml".text = ''
    CompileFlags:
      Add:
        - "-I${pkgs.glibc.dev}/include"
        - "-I${pkgs.gcc}/include"
      Compiler: ${pkgs.gcc}/bin/gcc
  '';
}
