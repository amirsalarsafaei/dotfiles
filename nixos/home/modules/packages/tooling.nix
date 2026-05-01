{ pkgs, ... }:
[
  pkgs.nixd
  pkgs.nil
  pkgs.nixpkgs-fmt
  pkgs.statix
  pkgs.nixfmt

  pkgs.gopls
  pkgs.golangci-lint
  pkgs.delve
  pkgs.goimports-reviser
  pkgs.golangci-lint-langserver
  pkgs.gotestsum
  pkgs.sqlc

  pkgs.rustfmt
  pkgs.rust-analyzer
  pkgs.cargo

  pkgs.clang-tools
  pkgs.cppcheck
  pkgs.gdb
  pkgs.lldb

  pkgs.kotlin-language-server
  pkgs.ktlint

  pkgs.sqls

  pkgs.pyright
  pkgs.black
  pkgs.ruff
  pkgs.mypy

  pkgs.buf
  pkgs.protobuf
  pkgs.protolint

  pkgs.yaml-language-server
  pkgs.vscode-json-languageserver
  pkgs.yamllint
  pkgs.yamlfmt

  pkgs.typescript-language-server
  pkgs.eslint

  pkgs.lua-language-server
  pkgs.luaformatter
  pkgs.stylua

  pkgs.jdt-language-server

  pkgs.dockerfile-language-server
  pkgs.docker-compose-language-service
  pkgs.hadolint

  pkgs.prettier
  pkgs.efm-langserver
  pkgs.shellcheck
  pkgs.copilot-language-server
  pkgs.vimPlugins.telescope-fzf-native-nvim
]
