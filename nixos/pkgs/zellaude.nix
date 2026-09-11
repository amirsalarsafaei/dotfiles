# zellaude — a Claude Code-aware zellij status bar (tabs + mode + session +
# a live activity symbol per Claude pane). Not in nixpkgs, so it is built here
# the same way nixpkgs builds its own rust zellij plugins: a plain
# buildRustPackage (the repo's .cargo/config.toml pins the wasm32-wasip1
# target) run through zellijPlugins.wrapper, which flattens the output
# directory down to the single .wasm file home-manager's
# `programs.zellij.plugins` expects.
#
# Two things come out of here:
#   plugin - the .wasm, for programs.zellij.plugins
#   hook   - the Claude Code hook bridge, wired up in
#            home/modules/programs/development/claude-code.nix
{
  lib,
  bash,
  coreutils,
  fetchFromGitHub,
  jq,
  libnotify,
  pkgsCross,
  procps,
  writeShellScriptBin,
  zellij,
  zellijPlugins,
  # base16 hex colors (with "#"), from custom.theme.resolved.colors, and the
  # hexToRgb helper from home/modules/theme/lib.nix — both threaded in by
  # zelij.nix so the status-bar accents below stay in sync with the theme
  # instead of being hand-picked RGB literals. Optional: claude-code.nix
  # callPackages this file too but only wants `hook`, which never touches
  # `unwrapped`/`rgb`, so it has no theme to thread through.
  themeLib ? null,
  colors ? null,
}:

let
  version = "0.5.1";

  # render.rs's `Color` type is a bare (u8, u8, u8) tuple literal, so this
  # renders a base16 slot straight into Rust source as "r, g, b".
  rgb = slot: themeLib.hexToRgb colors.${slot};

  # A zellij plugin is a wasm module, so it is cross-compiled rather than built
  # for this machine. The lld / wasm-ld additions are the same workaround
  # nixpkgs applies to its own rust zellij plugins (pkgs/by-name/ze/zellij/
  # plugins/rust/default.nix): without them cargo reaches for the host linker
  # and the build dies on undefined references to zellij's host functions.
  wasmPkgs = pkgsCross.wasm32-wasip1;

  src = fetchFromGitHub {
    owner = "ishefi";
    repo = "zellaude";
    tag = "v${version}";
    hash = "sha256-PbI4gjaPbJZP2DD8eUhOy2IMqKkOWam8jkSdix/szv4=";
  };

  unwrapped =
    (wasmPkgs.rustPlatform.buildRustPackage {
      pname = "zellaude";
      inherit version src;

      cargoHash = "sha256-4tplwN0qGUhPZay/U03jgxbWl7sdgNL+H6HxCar7jo0=";

      # The plugin normally installs itself: on its first permission grant it
      # shells out to write ~/.config/zellij/plugins/zellaude-hook.sh and to
      # splice hook entries into ~/.claude/settings.json with jq. Both of those
      # are Nix-managed here — settings.json is a read-only store symlink, so the
      # installer's `mv` over it fails on every single load — and the hook script
      # is exposed as `hook` below instead. Cutting the call is the whole patch;
      # the module it calls into is left in place so the diff stays one line.
      # Status-bar accent colors are hardcoded RGB constants in render.rs, not
      # sourced from the zellij/Stylix theme, and upstream's default is
      # purple. Repointed here at real base16 slots (base0D blue / base0C
      # cyan / base01-02 backgrounds) via `rgb`, so a theme change propagates
      # instead of leaving stale literals behind.
      postPatch = ''
        substituteInPlace src/main.rs \
          --replace-fail 'installer::run_install();' \
            '/* installer disabled: hooks are declared in claude-code.nix */'
      ''
      + lib.optionalString (themeLib != null) ''
        substituteInPlace src/render.rs \
          --replace-fail 'const PREFIX_BG: Color = (60, 50, 80);' \
            'const PREFIX_BG: Color = (${rgb "base02"});' \
          --replace-fail 'const PREFIX_BG_SETTINGS: Color = (100, 70, 140);' \
            'const PREFIX_BG_SETTINGS: Color = (${rgb "base0C"});' \
          --replace-fail 'const TAB_BG_ACTIVE: Color = (140, 100, 200);' \
            'const TAB_BG_ACTIVE: Color = (${rgb "base0D"});' \
          --replace-fail 'const TAB_BG_INACTIVE: Color = (80, 75, 110);' \
            'const TAB_BG_INACTIVE: Color = (${rgb "base01"});' \
          --replace-fail 'InputMode::Tab => ((180, 140, 255), "TAB"),' \
            'InputMode::Tab => ((${rgb "base0D"}), "TAB"),' \
          --replace-fail 'InputMode::Session => ((180, 140, 255), "SESSION"),' \
            'InputMode::Session => ((${rgb "base0C"}), "SESSION"),'
      '';

      # No test harness in the crate, and `cargo test` would want a host-target
      # build of a wasm-only plugin.
      doCheck = false;

      meta = {
        description = "Claude Code-aware status bar plugin for Zellij";
        homepage = "https://github.com/ishefi/zellaude";
        license = lib.licenses.mit;
        # No platforms list on purpose: this derivation's hostPlatform is
        # wasm32-wasip1, which no lib.platforms set contains, so naming one here
        # makes nixpkgs refuse to evaluate the package at all.
      };
    }).overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ wasmPkgs.lld ];
        env = (old.env or { }) // {
          RUSTFLAGS = (old.env.RUSTFLAGS or "") + " -C linker=wasm-ld";
        };
      });
in
{
  inherit unwrapped;

  plugin = zellijPlugins.wrapper "zellaude" unwrapped;

  # Exposed so a base16 slot's patched-in RGB triple can be checked without
  # rebuilding, e.g. `nix eval --impure --expr '(import ./pkgs/zellaude.nix
  # <args>).rgb "base0D"'` reads back "91, 156, 246".
  inherit rgb;

  # Claude Code hook -> `zellij pipe` bridge, straight from the repo. It is
  # wrapped rather than rewritten because it is the counterpart to the plugin's
  # own pipe protocol and has to stay in step with it. Deliberately not
  # writeShellApplication: the script opens with `[ -z "$ZELLIJ_SESSION_NAME" ]
  # && exit 0` guards, which return 1 when the variable *is* set, so `set -e`
  # would kill the script exactly when it has work to do.
  hook = writeShellScriptBin "zellaude-hook" ''
    export PATH=${
      lib.makeBinPath [
        coreutils
        jq
        libnotify # notify-send, for the permission-request notification
        procps # ps, for the "is the terminal focused" walk
        zellij
      ]
    }''${PATH:+:$PATH}
    exec ${lib.getExe bash} ${src}/scripts/zellaude-hook.sh "$@"
  '';
}
