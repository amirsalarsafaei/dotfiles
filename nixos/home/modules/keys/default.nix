# One registry of keyboard shortcuts, two consumers: the apps' own configs and
# a cheatsheet.
#
# The cheatsheet is a `keys` script built here, rendering registry.nix's rows
# through fzf (or plain text, or rofi).
#
# Everything is derived, so `keys` can never disagree with the config that is
# actually loaded:
#
#   registry.nix ──> lib.nix emitters ──> hyprland / tmux / zellij / ghostty
#                └─> rows ─────────────> keys TUI (fzf), rofi (Super+/), plain text
#
# nvim is the exception, and deliberately so: its keymaps are already declared
# with descriptions in nixvim, and it ships which-key. They are harvested from
# programs.nixvim.keymaps below rather than restated here. (Keymaps a plugin
# sets through its own options are not visible there — which-key shows those
# in-editor.)
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

  # Which apps to document on this host. A headless box has no hyprland
  # bindings to show, and listing them would be a lie.
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

  # tmux's copy-mode table is not reached through the prefix, so those rows get
  # their own label instead of the prefix.
  tmuxCopyMode = lib.partition (b: (b.table or null) != null) registry.tmux.binds;

  # nixvim's `desc` is optional and defaults to null, and an action can be raw
  # lua rather than a string, so fall back in both cases.
  nvimDesc =
    km:
    let
      desc = km.options.desc or null;
    in
    if desc != null then
      desc
    # Without a desc the action is all there is; drop the <cmd>…<cr> wrapper so
    # the row reads as a command rather than as vim notation.
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

  # wlogout's power menu is modal and already declares label + keybind per
  # button, so its rows are read off that layout rather than restated.
  wlogoutRows = map (button: {
    app = "wlogout";
    group = "Power menu";
    # The menu itself opens on Super+Esc (see the hyprland section of the
    # registry), and its keys only exist while it is up.
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
      rowsFor { app = "zellij"; } (registry.zellij.navigation ++ registry.zellij.enterPrefix)
      ++ rowsFor {
        app = "zellij";
        prefix = registry.zellij.prefix;
      } registry.zellij.prefixed
      ++ rowsFor {
        app = "zellij";
        prefix = "${registry.zellij.prefix} [ then";
      } registry.zellij.scroll
      ++ rowsFor { app = "zellij"; } registry.zellij.docs
    )
    ++ lib.optionals enabled.ghostty (rowsFor { app = "ghostty"; } registry.ghostty.binds)
    ++ lib.optionals enabled.wlogout wlogoutRows
    ++ lib.optionals enabled.zsh (rowsFor { app = "zsh"; } registry.zsh.docs)
    ++ lib.optionals enabled.nvim nvimRows;

  rowsJson = pkgs.writeText "keybindings.json" (builtins.toJSON rows);

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

      # app filter -> tab-separated rows, in registry order.
      select_rows() {
        jq -r --arg app "''${1:-}" '
          .[]
          | select($app == "" or .app == $app)
          | [ .app, (.group // ""), .keys, .desc ]
          | @tsv
        ' "$db"
      }

      # Grouped by app and section, in the order the registry declares them.
      # A section that is declared in two places (zellij's pane bindings come
      # from three blocks) still prints under one heading.
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
          # rofi comes from the ambient PATH rather than runtimeInputs: only
          # the graphical hosts have it, and only they bind Super+/.
          select_rows "''${2:-}" \
            | gawk -F'\t' '{ printf "[%s] %-28s %s\n", $1, $3, $4 }' \
            | rofi -dmenu -i -no-custom -p "  keybindings" \
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
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression "{ zjSshSplit = lib.getExe zjSshSplit; }";
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
    _module.args.keysLib = keysLib;

    custom.keys = {
      inherit registry rows;

      rendered = {
        hyprland = keysLib.hypr.render {
          inherit (registry.hyprland) binds submaps;
        };
        tmux = keysLib.tmux.render registry.tmux.binds;
        zellij = keysLib.zellij.render {
          # Ctrl-h is zellij's default way into Move mode; it is freed here so
          # the vim-navigator binding below can have it. Ctrl-o/g/p/n/t are
          # zellij's other default mode-entry keys (Session/Locked/Pane/
          # Resize/Tab); freeing them too means Ctrl-b is the only way into
          # any zellij mode, so no stray Ctrl-<key> steals a keystroke the
          # shell or an app expects (Ctrl-o for Claude Code's overlay, Ctrl-p
          # for shell history, etc).
          unbind = [
            (keysLib.on.ctrl keysLib.K.h)
            (keysLib.on.ctrl keysLib.K.o)
            (keysLib.on.ctrl keysLib.K.g)
            (keysLib.on.ctrl keysLib.K.p)
            (keysLib.on.ctrl keysLib.K.n)
            (keysLib.on.ctrl keysLib.K.t)
          ];
          sections = [
            (keysLib.zellij.section {
              selector = ''shared_except "locked" "tmux"'';
              binds = registry.zellij.navigation;
              note = ''
                Seamless nvim <-> pane navigation. This is only half of the
                mechanism: the plugin notices the focused pane is running nvim
                and writes the key through to it. Moving between nvim's own
                windows is zellij-nav.nvim's job, wired up in
                home/modules/neovim/navigation.nix.'';
            })
            (keysLib.zellij.section {
              selector = ''shared_except "tmux" "locked"'';
              binds = registry.zellij.enterPrefix;
            })
            (keysLib.zellij.section {
              selector = "tmux";
              binds = registry.zellij.prefixed;
            })
            (keysLib.zellij.section {
              selector = "scroll";
              binds = registry.zellij.scroll;
              note = ''
                Zellij's Copy action copies the *mouse* selection and nothing
                else, so there is no keyboard select-and-yank to bind.
                EditScrollback is the stand-in and is strictly more capable:
                the whole buffer opens in nvim, where selecting is visual mode
                and the yank reaches the system clipboard (clipboard =
                "unnamedplus"). Bound to "y" for the tmux muscle memory.'';
            })
            (keysLib.zellij.section {
              selector = "search";
              binds = registry.zellij.search;
            })
            (keysLib.zellij.section {
              selector = "locked";
              binds = [ (keysLib.zellij.unbind { key = keysLib.on.ctrl keysLib.K.g; }) ];
              note = ''
                Locked mode's own exit bind (Ctrl-g, back to Normal) lives in
                this block, not one of the shared groups above, so the
                top-level unbind can't reach it. Left bound it meant Ctrl-g
                got intercepted to leave Locked mode instead of reaching the
                app underneath (e.g. fzf's own Ctrl-g), defeating the point
                of autolock passing keys through untouched. There is
                deliberately no key left to exit Locked mode manually;
                autolock already does it automatically once the trigger
                process (fzf|lazygit|yazi|less|man) loses focus.'';
            })
          ];
        };
        ghostty = keysLib.ghostty.render registry.ghostty.binds;
      };

      # The rofi picker Super+/ opens. Declared here rather than in
      # hyprland.nix so the binding and the viewer stay one thing.
      commands.keysRofi = "${lib.getExe keysScript} --rofi";
    };

    home.packages = [
      keysScript
    ]
    ++ lib.optional enabled.zellij (
      # Kept as its own command because home/modules/navi-cheats/zellij.cheat
      # calls it by name.
      pkgs.writeShellScriptBin "zellij-keys" ''
        exec ${lib.getExe keysScript} --plain zellij
      ''
    );

    # Read by the `keys` script at runtime, which keeps the script itself
    # independent of the registry's content (and free of a store-path cycle:
    # a hyprland binding runs the very script that lists the bindings).
    xdg.configFile."keys/keybindings.json".source = rowsJson;
  };
}
