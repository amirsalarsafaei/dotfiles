# Keybinding vocabulary shared by every app in this config.
#
# Why this exists: a chord used to be written three times — once in the app's
# own config syntax, once in a hand-maintained cheatsheet, once in prose — and
# the copies drifted (see the note that used to sit above zjKeys in zelij.nix).
# Here a binding is declared once, as data: a *named* chord plus a description.
# The emitters below turn that data into hyprlang / tmux / zellij KDL / ghostty
# syntax, and home/modules/keys/default.nix turns the same data into the
# cheatsheet. Adding a shortcut in registry.nix updates the config and the
# cheatsheet together, by construction.
#
# Pure — no `config`, no `pkgs` — so it can be imported from anywhere.
{ lib }:
let
  # ── keys ────────────────────────────────────────────────────────────────
  # A key is a token, never a bare string, because every app spells the same
  # physical key differently: Return is RETURN in hyprlang, Enter in zellij's
  # KDL, enter in ghostty. The spellings live here once and each emitter reads
  # its own column. `null` means "this app has no name for this key"; using
  # such a key for that app is a build-time error rather than a binding that
  # silently does nothing.
  mkKey =
    {
      id,
      label ? id,
      hypr ? null,
      tmux ? null,
      zellij ? null,
      ghostty ? null,
    }:
    {
      inherit
        id
        label
        hypr
        tmux
        zellij
        ghostty
        ;
    };

  keyFor =
    app: key:
    let
      spelling = key.${app};
    in
    if spelling == null then
      throw "keys: key '${key.id}' has no ${app} spelling — add one in home/modules/keys/lib.nix"
    else
      spelling;

  # Letters and digits spell the same everywhere. Uppercase letters are their
  # own tokens rather than shift+letter, because that is how tmux and zellij
  # see them; hyprland wants an explicit SHIFT modifier alongside, and ghostty
  # has no uppercase form at all.
  letter =
    c:
    mkKey {
      id = c;
      hypr = c;
      tmux = c;
      zellij = c;
      ghostty = c;
    };
  upper =
    c:
    mkKey {
      id = c;
      hypr = c;
      tmux = c;
      zellij = c;
    };

  chars = s: lib.stringToCharacters s;

  named = {
    letters = lib.genAttrs (chars "abcdefghijklmnopqrstuvwxyz") letter;
    uppers = lib.genAttrs (chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ") upper;
    digits = lib.genAttrs (chars "0123456789") letter;
  };

  specials = {
    enter = mkKey {
      id = "enter";
      label = "Enter";
      hypr = "RETURN";
      tmux = "Enter";
      zellij = "Enter";
      ghostty = "enter";
    };
    space = mkKey {
      id = "space";
      label = "Space";
      hypr = "SPACE";
      tmux = "Space";
      zellij = "Space";
      ghostty = "space";
    };
    esc = mkKey {
      id = "esc";
      label = "Esc";
      hypr = "ESCAPE";
      tmux = "Escape";
      zellij = "Esc";
      ghostty = "escape";
    };
    escLower = mkKey {
      id = "escape";
      label = "Esc";
      hypr = "escape";
      zellij = "Esc";
    };
    tab = mkKey {
      id = "tab";
      label = "Tab";
      hypr = "TAB";
      tmux = "Tab";
      zellij = "Tab";
      ghostty = "tab";
    };
    backTab = mkKey {
      id = "backtab";
      label = "Shift+Tab";
      tmux = "BTab";
    };
    slash = mkKey {
      id = "slash";
      label = "/";
      hypr = "slash";
      tmux = "/";
      zellij = "/";
      ghostty = "slash";
    };
    minus = mkKey {
      id = "minus";
      label = "-";
      hypr = "minus";
      tmux = "-";
      zellij = "-";
      ghostty = "minus";
    };
    underscore = mkKey {
      id = "underscore";
      label = "_";
      tmux = "_";
      zellij = "_";
    };
    equal = mkKey {
      id = "equal";
      label = "=";
      hypr = "equal";
      tmux = "=";
      zellij = "=";
      ghostty = "equal";
    };
    plus = mkKey {
      id = "plus";
      label = "+";
      tmux = "+";
      zellij = "+";
    };
    pipe = mkKey {
      id = "pipe";
      label = "|";
      tmux = "|";
      zellij = "|";
    };
    less = mkKey {
      id = "less";
      label = "<";
      tmux = "<";
      zellij = "<";
    };
    greater = mkKey {
      id = "greater";
      label = ">";
      tmux = ">";
      zellij = ">";
    };
    braceOpen = mkKey {
      id = "braceopen";
      label = "{";
      zellij = "{";
    };
    braceClose = mkKey {
      id = "braceclose";
      label = "}";
      zellij = "}";
    };
    bracketOpen = mkKey {
      id = "bracketopen";
      label = "[";
      tmux = "[";
      zellij = "[";
    };
    bracketClose = mkKey {
      id = "bracketclose";
      label = "]";
      tmux = "]";
      zellij = "]";
    };
    comma = mkKey {
      id = "comma";
      label = ",";
      tmux = ",";
      zellij = ",";
    };
    period = mkKey {
      id = "period";
      label = ".";
      tmux = ".";
      zellij = ".";
    };
    semicolon = mkKey {
      id = "semicolon";
      label = ";";
      tmux = ";";
      zellij = ";";
    };
    bang = mkKey {
      id = "bang";
      label = "!";
      tmux = "!";
      zellij = "!";
    };
    # KDL quotes every bind key, so a literal double quote has to arrive here
    # already escaped — `bind "\""`, the same spelling zellij's own defaults use.
    dquote = mkKey {
      id = "dquote";
      label = "\"";
      tmux = "\"";
      zellij = "\\\"";
    };
    percent = mkKey {
      id = "percent";
      label = "%";
      tmux = "%";
      zellij = "%";
    };
    left = mkKey {
      id = "left";
      label = "←";
      hypr = "left";
      zellij = "Left";
    };
    right = mkKey {
      id = "right";
      label = "→";
      hypr = "right";
      zellij = "Right";
    };
    up = mkKey {
      id = "up";
      label = "↑";
      hypr = "up";
      zellij = "Up";
    };
    down = mkKey {
      id = "down";
      label = "↓";
      hypr = "down";
      zellij = "Down";
    };
    pageUp = mkKey {
      id = "pageup";
      label = "PgUp";
      zellij = "PageUp";
    };
    pageDown = mkKey {
      id = "pagedown";
      label = "PgDn";
      zellij = "PageDown";
    };
    printScreen = mkKey {
      id = "print";
      label = "PrtSc";
      hypr = "Print";
    };

    # Hyprland-only: pointer buttons and wheel, used by bindm / bind.
    mouseLeft = mkKey {
      id = "mouse-left";
      label = "Left-drag";
      hypr = "mouse:272";
    };
    mouseRight = mkKey {
      id = "mouse-right";
      label = "Right-drag";
      hypr = "mouse:273";
    };
    wheelDown = mkKey {
      id = "wheel-down";
      label = "Wheel↓";
      hypr = "mouse_down";
    };
    wheelUp = mkKey {
      id = "wheel-up";
      label = "Wheel↑";
      hypr = "mouse_up";
    };

    # Laptop function row (XF86 keysyms), Hyprland-only.
    volumeUp = mkKey {
      id = "volume-up";
      label = "Vol+";
      hypr = "XF86AudioRaiseVolume";
    };
    volumeDown = mkKey {
      id = "volume-down";
      label = "Vol−";
      hypr = "XF86AudioLowerVolume";
    };
    volumeMute = mkKey {
      id = "volume-mute";
      label = "Mute";
      hypr = "XF86AudioMute";
    };
    brightnessUp = mkKey {
      id = "brightness-up";
      label = "Bright+";
      hypr = "XF86MonBrightnessUp";
    };
    brightnessDown = mkKey {
      id = "brightness-down";
      label = "Bright−";
      hypr = "XF86MonBrightnessDown";
    };
    launchA = mkKey {
      id = "launch-a";
      label = "KbdLight";
      hypr = "XF86LaunchA";
    };
    kbdBrightnessDown = mkKey {
      id = "kbd-brightness-down";
      label = "KbdLight−";
      hypr = "XF86KbdBrightnessDown";
    };
  };

  K = named.letters // named.uppers // named.digits // specials;

  # ── modifiers ───────────────────────────────────────────────────────────
  M = {
    super = {
      id = "super";
      label = "Super";
      rank = 0;
      hypr = "SUPER";
      tmux = null;
      zellij = "Super";
      ghostty = "super";
    };
    ctrl = {
      id = "ctrl";
      label = "Ctrl";
      rank = 1;
      hypr = "CTRL";
      tmux = "C-";
      zellij = "Ctrl";
      ghostty = "ctrl";
    };
    alt = {
      id = "alt";
      label = "Alt";
      rank = 2;
      hypr = "ALT";
      tmux = "M-";
      zellij = "Alt";
      ghostty = "alt";
    };
    shift = {
      id = "shift";
      label = "Shift";
      rank = 3;
      hypr = "SHIFT";
      tmux = "S-";
      zellij = "Shift";
      ghostty = "shift";
    };
  };

  sortMods = mods: lib.sort (a: b: a.rank < b.rank) mods;

  modFor =
    app: mod:
    let
      spelling = mod.${app};
    in
    if spelling == null then
      throw "keys: modifier '${mod.id}' is not expressible in ${app}"
    else
      spelling;

  # ── chords ──────────────────────────────────────────────────────────────
  mkChord = mods: key: {
    mods = sortMods mods;
    inherit key;
  };

  # Named constructors, so a binding reads as `on.superShift K.Q` rather than
  # as the string "SUPER_SHIFT, Q".
  on = {
    none = mkChord [ ];
    super = mkChord [ M.super ];
    superShift = mkChord [
      M.super
      M.shift
    ];
    superCtrl = mkChord [
      M.super
      M.ctrl
    ];
    superAlt = mkChord [
      M.super
      M.alt
    ];
    ctrl = mkChord [ M.ctrl ];
    alt = mkChord [ M.alt ];
    shift = mkChord [ M.shift ];
    ctrlShift = mkChord [
      M.ctrl
      M.shift
    ];
    ctrlAlt = mkChord [
      M.ctrl
      M.alt
    ];
    altShift = mkChord [
      M.alt
      M.shift
    ];
  };

  # Human-readable form, used by the cheatsheet: "Super+Shift+Q", "Ctrl-b".
  human = chord: lib.concatStringsSep "+" ((map (m: m.label) chord.mods) ++ [ chord.key.label ]);

  toList = x: if lib.isList x then x else [ x ];

  # Indent a block, leaving blank lines blank rather than filled with spaces.
  indent =
    pad: text:
    lib.concatMapStringsSep "\n" (line: if line == "" then "" else "${pad}${line}") (
      lib.splitString "\n" text
    );

  # Emit `# group` / `// group` headers whenever the group changes, so the
  # generated config stays as readable as the hand-written one it replaced.
  withGroupHeaders =
    comment: renderOne: entries:
    let
      step =
        acc: entry:
        let
          header = lib.optional (entry.group or null != null && entry.group != acc.group) (
            (lib.optionalString (acc.lines != [ ]) "\n") + "${comment} ${entry.group}"
          );
        in
        {
          group = entry.group or acc.group;
          lines = acc.lines ++ header ++ [ (renderOne entry) ];
        };
      result = lib.foldl' step {
        group = null;
        lines = [ ];
      } entries;
    in
    lib.concatStringsSep "\n" result.lines;

  # ── hyprland (hyprlang) ─────────────────────────────────────────────────
  hyprChord =
    chord: "${lib.concatStringsSep "_" (map (modFor "hypr") chord.mods)}, ${keyFor "hypr" chord.key}";

  # bind/binde/bindm/bindel — hyprland's four flavors, named after what they
  # are for rather than after their suffix.
  hyprFlavors = {
    normal = "bind";
    repeat = "binde"; # held key repeats the dispatch
    mouse = "bindm"; # pointer drag
    media = "bindel"; # repeats *and* works on the lock screen (volume, backlight)
  };

  hypr = rec {
    bind =
      {
        on,
        dispatcher,
        arg ? null,
        desc,
        group ? null,
        flavor ? "normal",
      }:
      {
        app = "hyprland";
        inherit
          on
          dispatcher
          arg
          desc
          group
          flavor
          ;
      };

    exec =
      args@{ cmd, ... }:
      bind (
        (builtins.removeAttrs args [ "cmd" ])
        // {
          dispatcher = "exec";
          arg = cmd;
        }
      );

    line =
      b:
      let
        kw = hyprFlavors.${b.flavor};
        tail = lib.optionalString (b.arg != null) ", ${b.arg}";
      in
      "${kw} = ${hyprChord b.on}, ${b.dispatcher}${tail}";

    # A submap is a modal layer: <enter> opens it, every key inside acts
    # without a modifier, and Esc / Enter / <enter> again leave it. The exits
    # are generated so they can never be forgotten in one submap and present
    # in another.
    submap =
      {
        name,
        enter,
        desc,
        binds,
      }:
      {
        app = "hyprland";
        inherit
          name
          enter
          desc
          binds
          ;
      };

    # move/resize are the same submap with a different dispatcher: vi keys
    # nudge by `step`, Shift by `fine`, Ctrl by `coarse`.
    nudgeSubmap =
      {
        name,
        enter,
        dispatcher,
        desc,
        step ? 40,
        fine ? 10,
        coarse ? 100,
      }:
      let
        vector =
          direction: n:
          {
            h = "-${toString n} 0";
            l = "${toString n} 0";
            k = "0 -${toString n}";
            j = "0 ${toString n}";
          }
          .${direction};
        row =
          mods: n:
          map
            (
              direction:
              bind {
                on = mkChord mods K.${direction};
                inherit dispatcher;
                arg = vector direction n;
                desc = "${desc} ${
                  {
                    h = "left";
                    l = "right";
                    k = "up";
                    j = "down";
                  }
                  .${direction}
                }${lib.optionalString (n != step) " (${if n < step then "fine" else "coarse"})"}";
                flavor = "repeat";
              }
            )
            [
              "h"
              "j"
              "k"
              "l"
            ];
      in
      submap {
        inherit name enter desc;
        binds = row [ ] step ++ row [ M.shift ] fine ++ row [ M.ctrl ] coarse;
      };

    renderSubmap =
      s:
      lib.concatStringsSep "\n" (
        [
          "bind = ${hyprChord s.enter}, submap, ${s.name}"
          "submap = ${s.name}"
        ]
        ++ map line s.binds
        ++ [
          "bind = ${hyprChord (on.none K.escLower)}, submap, reset"
          "bind = ${hyprChord (on.none K.enter)}, submap, reset"
          "bind = ${hyprChord s.enter}, submap, reset"
          "submap = reset"
        ]
      );

    render =
      {
        binds ? [ ],
        submaps ? [ ],
      }:
      lib.concatStringsSep "\n\n" ([ (withGroupHeaders "#" line binds) ] ++ map renderSubmap submaps);
  };

  # ── tmux ────────────────────────────────────────────────────────────────
  # tmux keys are reached through the prefix (Ctrl-b here), so a chord carries
  # no Super and the cheatsheet prints the prefix in front of it.
  tmuxChord =
    chord: "${lib.concatStrings (map (modFor "tmux") chord.mods)}${keyFor "tmux" chord.key}";

  tmux = {
    bind =
      {
        on,
        run,
        desc,
        group ? null,
        repeat ? false, # -r: key can be repeated without re-pressing the prefix
        table ? null, # -T: e.g. copy-mode-vi
      }:
      {
        app = "tmux";
        inherit
          on
          run
          desc
          group
          repeat
          table
          ;
      };

    unbind =
      {
        key,
        group ? null,
      }:
      {
        app = "tmux";
        unbind = key;
        desc = null;
        inherit group;
      };

    line =
      b:
      if b ? unbind then
        "unbind ${keyFor "tmux" b.unbind}"
      else
        lib.concatStringsSep " " (
          [ "bind" ]
          ++ lib.optional b.repeat "-r"
          ++ lib.optionals (b.table != null) [
            "-T"
            b.table
          ]
          ++ [
            (tmuxChord b.on)
            b.run
          ]
        );

    render = binds: withGroupHeaders "#" tmux.line binds;
  };

  # ── zellij (KDL) ────────────────────────────────────────────────────────
  zellijChord =
    chord:
    lib.concatStringsSep " " ((map (modFor "zellij") chord.mods) ++ [ (keyFor "zellij" chord.key) ]);

  zellij = {
    # `on` may be several chords: zellij allows one action block to answer to
    # more than one key (`bind "b" "!" { BreakPane; }`).
    bind =
      {
        on,
        run,
        desc,
        group ? null,
      }:
      {
        app = "zellij";
        on = toList on;
        run = toList run;
        inherit desc group;
      };

    # A mode block: `tmux { ... }`, `shared_except "locked" "tmux" { ... }`.
    # `mode` is a single mode name; `except` is the list of modes a
    # shared_except block leaves out. The KDL `selector` is derived from these
    # so the collision check can also see which modes a section targets.
    section =
      {
        mode ? null,
        except ? null,
        binds,
        note ? null,
      }:
      let
        selector =
          if except != null then
            "shared_except ${lib.concatMapStringsSep " " (m: "\"${m}\"") except}"
          else
            mode;
      in
      {
        inherit
          selector
          binds
          note
          mode
          except
          ;
      };

    line =
      b:
      let
        keys = lib.concatMapStringsSep " " (c: ''"${zellijChord c}"'') b.on;
        multiline = lib.any (a: lib.hasInfix "\n" a) b.run;
        body =
          if multiline then
            "\n" + lib.concatMapStringsSep "\n" (indent "    ") b.run + "\n"
          else
            " " + lib.concatStringsSep " " b.run + " ";
      in
      "bind ${keys} {${body}}";

    renderSection =
      s:
      lib.concatStringsSep "\n" (
        lib.optional (s.note != null) (
          lib.concatMapStringsSep "\n" (l: "// ${l}") (lib.splitString "\n" s.note)
        )
        ++ [ "${s.selector} {" ]
        ++ [ (indent "    " (withGroupHeaders "//" zellij.line s.binds)) ]
        ++ [ "}" ]
      );

    # The whole `keybinds` node, ready to drop into zellij's config: a second
    # keybinds node would be ignored, so this has to be the only one.
    #
    # `clear-defaults=true` is the reason the sections below can be read as the
    # whole keymap. Without it zellij *merges* what is declared here into its
    # own defaults, so a chord it already binds fires both actions and the only
    # way to take one back is an `unbind` — which in 0.44.3 dead-ends the key
    # entirely if it is then re-bound. Starting from nothing costs a longer
    # registry and buys a keymap that is exactly what the file says.
    render =
      {
        sections ? [ ],
      }:
      ''
        keybinds clear-defaults=true {
        ${indent "    " (lib.concatMapStringsSep "\n\n" zellij.renderSection sections)}
        }'';
  };

  # ── ghostty ─────────────────────────────────────────────────────────────
  ghosttyChord =
    chord:
    lib.concatStringsSep "+" ((map (modFor "ghostty") chord.mods) ++ [ (keyFor "ghostty" chord.key) ]);

  ghostty = {
    bind =
      {
        on,
        action,
        desc,
        group ? null,
      }:
      {
        app = "ghostty";
        inherit
          on
          action
          desc
          group
          ;
      };

    # ghostty takes a list of "chord=action" strings, so there is nothing to
    # lay out — the list *is* the config.
    render = binds: map (b: "${ghosttyChord b.on}=${b.action}") binds;
  };

  # ── collision checks ────────────────────────────────────────────────────
  # Both return a list of error strings (empty = clean). default.nix throws on
  # any non-empty result, so a bad bind fails the build instead of silently
  # double-firing at runtime.

  # A chord bound more than once within one namespace. `entries` is a list of
  # binds, each with `.on` (a chord or a list of chords); `chordF` canonicalizes
  # a chord to its string form for that app.
  duplicatesIn =
    chordF: namespace: entries:
    let
      flat = lib.concatMap (b: map (c: chordF c) (toList b.on)) entries;
      count = lib.foldl' (acc: c: acc // { ${c} = (acc.${c} or 0) + 1; }) { } flat;
      dups = lib.filterAttrs (_: n: n > 1) count;
    in
    lib.mapAttrsToList (c: n: "${namespace}: '${c}' is bound ${toString n} times") dups;

  # Every zellij mode, in the order zellij names them. Sections say which modes
  # they target (`mode = "pane"`, or `except = [ "locked" ]`), and the conflict
  # check below expands those into concrete modes against this list.
  zellijModes = [
    "normal"
    "locked"
    "resize"
    "pane"
    "move"
    "tab"
    "scroll"
    "search"
    "entersearch"
    "renametab"
    "renamepane"
    "session"
    "tmux"
  ];

  # One chord bound twice in the same mode. With clear-defaults there are no
  # hidden defaults left to collide with, so the only way to bind a key twice is
  # to declare it twice — which zellij resolves silently, leaving a key that
  # does the wrong thing.
  #
  # A mode block and a `shared_except` block are *not* a conflict: zellij lets
  # the mode-specific bind win, and the defaults rely on that (entersearch binds
  # Enter/Esc itself while shared_except "normal" "locked" also covers it). So
  # the two kinds are checked against themselves, not against each other.
  zellijModeConflicts =
    sections:
    let
      targetModes =
        s: if s.except != null then lib.filter (m: !(lib.elem m s.except)) zellijModes else [ s.mode ];

      # [{ mode, chord, kind, desc }] for every chord of every bind.
      entries = lib.concatMap (
        s:
        let
          kind = if s.except != null then "shared" else "mode";
        in
        lib.concatMap (
          b:
          lib.concatMap (
            c:
            map (mode: {
              inherit mode kind;
              chord = zellijChord c;
              desc = b.desc or "?";
            }) (targetModes s)
          ) (toList b.on)
        ) s.binds
      ) sections;

      byKey = lib.groupBy (e: "${e.mode}\t${e.kind}\t${e.chord}") entries;
    in
    lib.mapAttrsToList (
      _: es:
      let
        e = lib.head es;
      in
      "zellij ${e.mode} mode: '${e.chord}' is bound ${toString (lib.length es)} times (${
        lib.concatMapStringsSep ", " (x: x.desc) es
      })"
    ) (lib.filterAttrs (_: es: lib.length es > 1) byKey);

  # ── documentation-only entries ──────────────────────────────────────────
  # Shortcuts this config does not declare but a user still needs to know:
  # an app's own defaults (zellij's Alt-hjkl), or a technique rather than a
  # single chord (how to yank out of a scrollback). They reach the cheatsheet
  # and nothing else.
  doc =
    {
      keys,
      desc,
      group ? null,
    }:
    {
      inherit keys desc group;
      doc = true;
    };

  # ── cheatsheet rows ─────────────────────────────────────────────────────
  # One flat, app-agnostic shape for every consumer (the `keys` fzf TUI,
  # rofi, plain text). `keys` is already human-readable; `prefix` is folded
  # in here so a tmux row reads "Ctrl-b h" rather than a bare "h".
  rowsFor =
    {
      app,
      prefix ? null,
    }:
    binds:
    let
      chordText =
        b:
        if b ? doc then
          b.keys
        else if b ? unbind then
          null
        else
          lib.concatMapStringsSep " / " human (toList b.on);
      withPrefix = text: if prefix == null then text else "${prefix} ${text}";
    in
    map (b: {
      inherit app;
      group = b.group or null;
      keys = withPrefix (chordText b);
      desc = b.desc;
    }) (lib.filter (b: !(b ? unbind) && (b.desc or null) != null) binds);
in
{
  inherit
    K
    M
    on
    mkChord
    hyprChord
    tmuxChord
    ghosttyChord
    hypr
    tmux
    zellij
    ghostty
    doc
    rowsFor
    duplicatesIn
    zellijModeConflicts
    ;
}
