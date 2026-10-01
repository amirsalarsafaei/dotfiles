{ lib }:
let
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
    lidClose = mkKey {
      id = "lid-close";
      label = "Lid closed";
      hypr = "switch:on:Lid Switch";
    };
    lidOpen = mkKey {
      id = "lid-open";
      label = "Lid opened";
      hypr = "switch:off:Lid Switch";
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

  mkChord = mods: key: {
    mods = sortMods mods;
    inherit key;
  };

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

  joinChord =
    sep: modF: keyF: chord:
    lib.concatStringsSep sep (map modF chord.mods ++ [ (keyF chord.key) ]);

  human = joinChord "+" (m: m.label) (k: k.label);

  indent =
    pad: text:
    lib.concatMapStringsSep "\n" (line: if line == "" then "" else "${pad}${line}") (
      lib.splitString "\n" text
    );

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

  hyprChord =
    chord: "${lib.concatStringsSep "_" (map (modFor "hypr") chord.mods)}, ${keyFor "hypr" chord.key}";

  hyprFlavors = {
    normal = "bind";
    repeat = "binde";
    mouse = "bindm";
    media = "bindel";
    switch = "bindl";
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

  tmuxChord =
    chord: "${lib.concatStrings (map (modFor "tmux") chord.mods)}${keyFor "tmux" chord.key}";

  tmux = {
    bind =
      {
        on,
        run,
        desc,
        group ? null,
        repeat ? false,
        table ? null,
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

  zellijChord = joinChord " " (modFor "zellij") (keyFor "zellij");

  zellij = {
    bind =
      {
        on,
        run,
        desc,
        group ? null,
      }:
      {
        app = "zellij";
        on = lib.toList on;
        run = lib.toList run;
        inherit desc group;
      };

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

    render =
      {
        sections ? [ ],
      }:
      ''
        keybinds clear-defaults=true {
        ${indent "    " (lib.concatMapStringsSep "\n\n" zellij.renderSection sections)}
        }'';
  };

  ghosttyChord = joinChord "+" (modFor "ghostty") (keyFor "ghostty");

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

    render = binds: map (b: "${ghosttyChord b.on}=${b.action}") binds;
  };

  duplicatesIn =
    chordF: namespace: entries:
    let
      flat = lib.concatMap (b: map chordF (lib.toList b.on)) entries;
      count = lib.groupBy' (acc: _: acc + 1) 0 lib.id flat;
      dups = lib.filterAttrs (_: n: n > 1) count;
    in
    lib.mapAttrsToList (c: n: "${namespace}: '${c}' is bound ${toString n} times") dups;

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

  zellijModeConflicts =
    sections:
    let
      targetModes =
        s: if s.except != null then lib.filter (m: !(lib.elem m s.except)) zellijModes else [ s.mode ];

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
          ) (lib.toList b.on)
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
          lib.concatMapStringsSep " / " human (lib.toList b.on);
      withPrefix = text: if prefix == null then text else "${prefix} ${text}";
    in
    map (b: {
      inherit app;
      group = b.group or null;
      keys = withPrefix (chordText b);
      inherit (b) desc;
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
