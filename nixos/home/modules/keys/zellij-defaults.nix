# Zellij's built-in keybindings, transcribed from `zellij setup --dump-config`
# at version 0.44.3 (the version pinned by flake.lock).
#
# The build-time collision check (home/modules/keys/lib.nix) uses this to flag
# any declared bind that lands on a chord zellij already binds by default in the
# same mode. Zellij *merges* keybinds rather than replacing them, so such a bind
# would fire both actions — the bug that put "close pane" and the Claude picker
# on Ctrl+b x at once. The rule: to bind a default chord, `unbind` it first.
#
# Chord strings here are spelled exactly as zellij's KDL spells them ("Ctrl b",
# "Alt Shift p", "Left", …), which is the same form keysLib's `zellijChord`
# emitter produces — so the check compares strings directly.
#
# When zellij is upgraded, regenerate by running `zellij setup --dump-config`
# and re-transcribing the `keybinds { … }` block into the shape below.
{
  modes = [
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

  # Chords bound by default in exactly one named mode block.
  named = {
    normal = [ ]; # only a commented-out `bind "Alt c" { Copy; }`
    locked = [ "Ctrl g" ];
    resize = [
      "Ctrl n"
      "h" "Left"
      "j" "Down"
      "k" "Up"
      "l" "Right"
      "H" "J" "K" "L"
      "=" "+"
      "-"
    ];
    pane = [
      "Ctrl p"
      "h" "Left"
      "l" "Right"
      "j" "Down"
      "k" "Up"
      "p" "n" "d" "r" "s"
      "x" "f" "z" "w" "e"
      "c" "i"
    ];
    move = [
      "Ctrl h"
      "n" "Tab"
      "p"
      "h" "Left"
      "j" "Down"
      "k" "Up"
      "l" "Right"
    ];
    tab = [
      "Ctrl t"
      "r"
      "h" "Left" "Up" "k"
      "l" "Right" "Down" "j"
      "n" "x" "s" "b"
      "]" "["
      "1" "2" "3" "4" "5" "6" "7" "8" "9"
      "Tab"
    ];
    scroll = [
      "Ctrl s"
      "e" "s"
      "Ctrl c"
      "j" "Down"
      "k" "Up"
      "Ctrl f" "PageDown" "Right" "l"
      "Ctrl b" "PageUp" "Left" "h"
      "d" "u"
    ];
    search = [
      "Ctrl s"
      "Ctrl c"
      "j" "Down"
      "k" "Up"
      "Ctrl f" "PageDown" "Right" "l"
      "Ctrl b" "PageUp" "Left" "h"
      "d" "u"
      "n" "p" "c" "w" "o"
    ];
    entersearch = [
      "Ctrl c" "Esc"
      "Enter"
    ];
    renametab = [ "Ctrl c" "Esc" ];
    renamepane = [ "Ctrl c" "Esc" ];
    session = [
      "Ctrl o" "Ctrl s"
      "d" "w" "c" "p" "a" "s" "l"
    ];
    tmux = [
      "["
      "Ctrl b"
      "\"" "%"
      "z" "c" ","
      "p" "n"
      "Left" "Right" "Down" "Up"
      "h" "l" "j" "k"
      "o" "d"
      "Space"
      "x"
    ];
  };

  # `shared_except "A" "B" { … }` blocks: the chords apply to every mode except
  # those listed.
  sharedExcept = [
    {
      except = [ "locked" ];
      chords = [
        "Ctrl g" "Ctrl q"
        "Alt f" "Alt n"
        "Alt i" "Alt o"
        "Alt h" "Alt Left"
        "Alt l" "Alt Right"
        "Alt j" "Alt Down"
        "Alt k" "Alt Up"
        "Alt =" "Alt +"
        "Alt -"
        "Alt [" "Alt ]"
        "Alt p"
        "Alt Shift p"
      ];
    }
    { except = [ "normal" "locked" ]; chords = [ "Enter" "Esc" ]; }
    { except = [ "pane" "locked" ]; chords = [ "Ctrl p" ]; }
    { except = [ "resize" "locked" ]; chords = [ "Ctrl n" ]; }
    { except = [ "scroll" "locked" ]; chords = [ "Ctrl s" ]; }
    { except = [ "session" "locked" ]; chords = [ "Ctrl o" ]; }
    { except = [ "tab" "locked" ]; chords = [ "Ctrl t" ]; }
    { except = [ "move" "locked" ]; chords = [ "Ctrl h" ]; }
    { except = [ "tmux" "locked" ]; chords = [ "Ctrl b" ]; }
  ];
}
