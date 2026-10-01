{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.keys;

  keysLib = import ./lib.nix { inherit lib; };

  registry = import ./registry.nix {
    inherit lib keysLib;
    cmd = cfg.commands;
  };

  enabled = {
    hyprland = config.wayland.windowManager.hyprland.enable or false;
    tmux = config.programs.tmux.enable or false;
    zellij = config.programs.zellij.enable or false;
    ghostty = config.programs.ghostty.enable or false;
    nvim = config.programs.nixvim.enable or false;
    wlogout = config.programs.wlogout.enable or false;
    zsh = config.programs.zsh.enable or false;
  };

  inherit (keysLib) rowsFor;

  tmuxCopyMode = lib.partition (b: (b.table or null) != null) registry.tmux.binds;

  nvimDesc =
    km:
    let
      desc = km.options.desc or null;
    in
    if desc != null then
      desc
    else if lib.isString km.action then
      lib.removeSuffix "<CR>" (
        lib.removeSuffix "<cr>" (lib.removePrefix "<Cmd>" (lib.removePrefix "<cmd>" km.action))
      )
    else
      "(lua function)";

  nvimRows = map (km: {
    app = "nvim";
    group = "Mode ${lib.concatStringsSep "/" (lib.toList km.mode)}";
    keys = km.key;
    desc = nvimDesc km;
  }) config.programs.nixvim.keymaps;

  nvimLspRows =
    let
      lsp = config.programs.nixvim.plugins.lsp.keymaps;

      strip = value: lib.removePrefix "vim.lsp.buf." (lib.removePrefix "vim.diagnostic." value);

      fromAttrs =
        group: attrs:
        lib.mapAttrsToList (key: value: {
          app = "nvim";
          inherit group;
          keys = key;
          desc = strip (if lib.isAttrs value then value.action else value);
        }) attrs;
    in
    fromAttrs "LSP diagnostics" lsp.diagnostic
    ++ fromAttrs "LSP (buffer-local)" lsp.lspBuf
    ++ map (km: {
      app = "nvim";
      group = "LSP (buffer-local)";
      keys = km.key;
      desc = km.options.desc or "(lua function)";
    }) lsp.extra;

  wlogoutRows = map (button: {
    app = "wlogout";
    group = "Power menu";
    keys = "Super+Esc then ${button.keybind}";
    desc = button.text or button.label;
  }) (lib.filter (button: button ? keybind) config.programs.wlogout.layout);

  rows =
    lib.optionals enabled.hyprland (
      rowsFor { app = "hyprland"; } registry.hyprland.binds
      ++ rowsFor { app = "hyprland"; } registry.hyprland.docs
    )
    ++ lib.optionals enabled.tmux (
      rowsFor {
        app = "tmux";
        prefix = registry.tmux.prefix;
      } tmuxCopyMode.wrong
      ++ rowsFor {
        app = "tmux";
        prefix = "copy-mode";
      } tmuxCopyMode.right
    )
    ++ lib.optionals enabled.zellij (
      let
        inherit (registry.zellij) prefix;
        inMode =
          via: binds:
          rowsFor {
            app = "zellij";
            prefix = "${prefix} ${via} then";
          } binds;
      in
      rowsFor { app = "zellij"; } registry.zellij.navigation
      ++ rowsFor { app = "zellij"; } registry.zellij.prefixEnter
      ++ rowsFor { app = "zellij"; } registry.zellij.leaveMode
      ++ rowsFor {
        app = "zellij";
        inherit prefix;
      } registry.zellij.prefixed
      ++ inMode "Ctrl+p" registry.zellij.paneMode
      ++ inMode "Ctrl+t" registry.zellij.tabMode
      ++ inMode "Ctrl+n" registry.zellij.resizeMode
      ++ inMode "m" registry.zellij.moveMode
      ++ inMode "Ctrl+o" registry.zellij.sessionMode
      ++ inMode "[" registry.zellij.scrollMode
      ++ inMode "[ s" registry.zellij.searchMode
      ++ rowsFor { app = "zellij"; } registry.zellij.docs
    )
    ++ lib.optionals enabled.ghostty (rowsFor { app = "ghostty"; } registry.ghostty.binds)
    ++ lib.optionals enabled.wlogout wlogoutRows
    ++ lib.optionals enabled.zsh (rowsFor { app = "zsh"; } registry.zsh.docs)
    ++ lib.optionals enabled.nvim (nvimRows ++ nvimLspRows);

  zellijSections = [
    (keysLib.zellij.section {
      except = [
        "locked"
        "tmux"
      ];
      binds = registry.zellij.navigation ++ registry.zellij.prefixEnter;
    })
    (keysLib.zellij.section {
      except = [
        "normal"
        "locked"
      ];
      binds = registry.zellij.leaveMode;
    })
    (keysLib.zellij.section {
      mode = "tmux";
      binds = registry.zellij.prefixed;
    })
    (keysLib.zellij.section {
      mode = "pane";
      binds = registry.zellij.paneMode;
    })
    (keysLib.zellij.section {
      mode = "tab";
      binds = registry.zellij.tabMode;
    })
    (keysLib.zellij.section {
      mode = "resize";
      binds = registry.zellij.resizeMode;
    })
    (keysLib.zellij.section {
      mode = "move";
      binds = registry.zellij.moveMode;
    })
    (keysLib.zellij.section {
      mode = "scroll";
      binds = registry.zellij.scrollMode;
    })
    (keysLib.zellij.section {
      mode = "search";
      binds = registry.zellij.searchMode;
    })
    (keysLib.zellij.section {
      mode = "entersearch";
      binds = registry.zellij.enterSearchMode;
    })
    (keysLib.zellij.section {
      mode = "renametab";
      binds = registry.zellij.renameTabMode;
    })
    (keysLib.zellij.section {
      mode = "renamepane";
      binds = registry.zellij.renamePaneMode;
    })
    (keysLib.zellij.section {
      mode = "session";
      binds = registry.zellij.sessionMode;
    })
  ];

  checkErrors =
    let
      dups =
        keysLib.duplicatesIn keysLib.hyprChord "hyprland" registry.hyprland.binds
        ++ lib.concatMap (
          s: keysLib.duplicatesIn keysLib.hyprChord "hyprland submap ${s.name}" s.binds
        ) registry.hyprland.submaps
        ++ lib.concatLists (
          lib.mapAttrsToList (table: binds: keysLib.duplicatesIn keysLib.tmuxChord "tmux ${table}" binds) (
            lib.groupBy (b: if b.table or null == null then "prefix" else b.table) (
              lib.filter (b: b ? on) registry.tmux.binds
            )
          )
        )
        ++ keysLib.duplicatesIn keysLib.ghosttyChord "ghostty" registry.ghostty.binds;
    in
    dups ++ keysLib.zellijModeConflicts zellijSections;

  rowsJson = pkgs.writeText "keybindings.json" (
    if checkErrors == [ ] then
      builtins.toJSON rows
    else
      throw (builtins.concatStringsSep "\n" checkErrors)
  );

  keysScript = pkgs.writeShellApplication {
    name = "keys";
    runtimeInputs = [
      pkgs.fzf
      pkgs.jq
      pkgs.gawk
      pkgs.coreutils
    ];
    text = ''
      db="''${XDG_CONFIG_HOME:-$HOME/.config}/keys/keybindings.json"

      select_rows() {
        jq -r --arg app "''${1:-}" '
          .[]
          | select($app == "" or .app == $app)
          | [ .app, (.group // ""), .keys, .desc ]
          | @tsv
        ' "$db"
      }

      plain() {
        select_rows "''${1:-}" | gawk -F'\t' '
          {
            rows[NR] = $0
            key = $1 SUBSEP $2
            if (!(key in seen)) { seen[key] = ++groups; name[groups] = key }
            group_of[NR] = seen[key]
            if (length($3) > width) width = length($3)
          }
          END {
            for (g = 1; g <= groups; g++) {
              split(name[g], head, SUBSEP)
              printf "\n%s%s\n", head[1], (head[2] == "" ? "" : "  ·  " head[2])
              for (i = 1; i <= NR; i++) {
                if (group_of[i] != g) continue
                split(rows[i], f, "\t")
                printf "  %-*s  %s\n", width, f[3], f[4]
              }
            }
          }
        '
      }

      tui() {
        select_rows "''${1:-}" \
          | gawk -F'\t' '{ printf "%-10s  %-22s  %-28s  %s\n", $1, $2, $3, $4 }' \
          | fzf --height=100% --reverse --prompt='  keys  ' \
              --header='type to fuzzy filter · enter/esc to close'
      }

      case "''${1:-}" in
        "")
          tui || true
          ;;
        -p | --plain)
          plain "''${2:-}"
          ;;
        -r | --rofi)
          palette="''${XDG_CONFIG_HOME:-$HOME/.config}/theme/current.json"
          pick() { jq -r "$1 // empty" "$palette" 2>/dev/null || true; }
          select_rows "''${2:-}" \
            | gawk -F'\t' \
                -v mono="$(pick .fonts.mono)" \
                -v tag="$(pick .accents.primary)" \
                -v key="$(pick .colors.base07)" \
                -v note="$(pick .colors.base03)" '
                function esc(s) {
                  gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s)
                  return s
                }
                function paint(c) { return c == "" ? "" : " foreground=\"" c "\"" }
                BEGIN { face = mono == "" ? "monospace" : mono }
                {
                  printf "<span font_family=\"%s\"><span%s>%s</span><span%s weight=\"medium\">%s</span></span>  %s<span%s size=\"small\">   %s</span>\n",
                    face, paint(tag), esc(sprintf("%-10s", $1)), paint(key), esc(sprintf("%-26s", $3)),
                    esc($4), paint(note), esc(tolower($2))
                }' \
            | rofi -dmenu -i -no-custom -markup-rows -p "  keybindings" \
                -theme-str 'window { width: calc( 92% min 1180px ); }
                  listview { lines: 14; spacing: 0px; }
                  element { children: [ element-text ]; padding: 7px 16px; }' \
                -mesg "Generated from the Nix keybinding registry — type to filter, Esc to close" \
            >/dev/null || true
          ;;
        -j | --json)
          cat "$db"
          ;;
        -h | --help)
          cat <<'EOF'
      keys — every keyboard shortcut this machine is configured with

        keys                 fuzzy-searchable TUI (fzf)
        keys --plain [app]   plain text, grep-friendly
        keys --rofi [app]    rofi picker (bound to Super+/ in hyprland)
        keys --json          the raw rows

      Apps: hyprland, tmux, zellij, ghostty, nvim, wlogout, zsh
      Declared in home/modules/keys/registry.nix — edit there, then rebuild.
      EOF
          ;;
        *)
          plain "$1"
          ;;
      esac
    '';
  };
in
{
  options.custom.keys = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Declare keybindings centrally and install the `keys` cheatsheet.";
    };

    commands = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.str;
      default = { };
      example = lib.literalExpression "{ agentsPick = lib.getExe agentsPick; }";
      description = ''
        Commands that bindings in registry.nix run, keyed by the name the
        registry uses. Set by whichever module builds the command, so the
        registry never has to reach for `pkgs`.
      '';
    };

    registry = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      readOnly = true;
      description = "The parsed keybinding registry.";
    };

    rendered = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      readOnly = true;
      description = "Per-app config text generated from the registry.";
    };

    rows = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf (lib.types.nullOr lib.types.str));
      internal = true;
      readOnly = true;
      description = "Flat cheatsheet rows: app, group, keys, desc.";
    };
  };

  config = lib.mkIf cfg.enable {
    custom.keys = {
      inherit registry rows;

      rendered = {
        hyprland = keysLib.hypr.render {
          inherit (registry.hyprland) binds submaps;
        };
        tmux = keysLib.tmux.render registry.tmux.binds;
        zellij = keysLib.zellij.render { sections = zellijSections; };
        ghostty = keysLib.ghostty.render registry.ghostty.binds;
      };

      commands.keysRofi = "${lib.getExe keysScript} --rofi";
    };

    home.packages = [
      keysScript
    ]
    ++ lib.optional enabled.zellij (
      pkgs.writeShellScriptBin "zellij-keys" ''
        exec ${lib.getExe keysScript} --plain zellij
      ''
    );

    xdg.configFile."keys/keybindings.json".source = rowsJson;
  };
}
