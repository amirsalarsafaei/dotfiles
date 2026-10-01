{ pkgs, ... }:
let
  luaPackages = pkgs.lua.withPackages (ps: [
    ps.luafilesystem
    ps.luasocket
    ps.penlight
    ps.busted
    ps.cjson
    ps.luarocks
    ps.basexx
    ps.dkjson
  ]);

  vitejs = pkgs.vitejs.override {
    fetchPnpmDeps = args: pkgs.fetchPnpmDeps (args // { pnpm = pkgs.pnpm_10; });
  };
in
{
  home.packages = [
    pkgs.go
    pkgs.rustc
    pkgs.nodejs_22
    pkgs.gcc
    pkgs.libgcc
    pkgs.python3
    pkgs.uv
    luaPackages

    pkgs.cmake
    pkgs.pkg-config
    pkgs.openssl_3
    pkgs.gnumake
    pkgs.just
    pkgs.devenv
    pkgs.gh
    pkgs.git-crypt
    pkgs.sops
    pkgs.unzip
    pkgs.gore
    pkgs.devbox
    pkgs.bazelisk
    pkgs.amp-cli
    pkgs.codex
    pkgs.opencode
    pkgs.pnpm
    vitejs
    pkgs.lazygit
    pkgs.step-cli
    pkgs.bun
    pkgs.luaPackages.tree-sitter-cli
    pkgs.buildah
    pkgs.podman
    pkgs.ast-grep
    pkgs.istioctl
    pkgs.jfrog-cli
    pkgs.crit
  ];
}
