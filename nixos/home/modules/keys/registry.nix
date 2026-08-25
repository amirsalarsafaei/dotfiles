# Every keyboard shortcut this configuration declares, in one place.
#
# Each entry names its chord (`on.superShift K.Q`, not "SUPER_SHIFT, Q") and
# carries the description that the cheatsheet shows. home/modules/keys/lib.nix
# renders these into each app's own config syntax; nothing else in the repo
# writes a bind line by hand.
#
# `cmd` holds the store paths of commands a binding runs. They come from
# custom.keys.commands, set by the module that builds the command, so this file
# stays free of package plumbing.
{
  lib,
  keysLib,
  cmd,
}:
let
  inherit (keysLib)
    K
    M
    on
    mkChord
    doc
    ;

  # vi directions, spelled once for every app that binds hjkl.
  directions = {
    h = {
      key = K.h;
      upper = K.H;
      hypr = "l";
      zellij = "Left";
      tmux = "L";
      word = "left";
    };
    j = {
      key = K.j;
      upper = K.J;
      hypr = "d";
      zellij = "Down";
      tmux = "D";
      word = "down";
    };
    k = {
      key = K.k;
      upper = K.K;
      hypr = "u";
      zellij = "Up";
      tmux = "U";
      word = "up";
    };
    l = {
      key = K.l;
      upper = K.L;
      hypr = "r";
      zellij = "Right";
      tmux = "R";
      word = "right";
    };
  };

  eachDirection =
    f:
    lib.concatMap (name: [ (f directions.${name}) ]) [
      "h"
      "j"
      "k"
      "l"
    ];
in
rec {
  # ── Hyprland ────────────────────────────────────────────────────────────
  hyprland = {
    binds = [
      (keysLib.hypr.exec {
        on = on.super K.enter;
        cmd = "$terminal";
        desc = "Open a terminal";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.space;
        cmd = "$menu";
        desc = "App launcher";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.slash;
        cmd = cmd.keysRofi;
        desc = "Show every keybinding";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.x;
        cmd = "loginctl lock-session";
        desc = "Lock the session";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.esc;
        cmd = "wlogout -p layer-shell";
        desc = "Power menu";
        group = "Session";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.Q;
        dispatcher = "exit";
        desc = "Quit Hyprland";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.N;
        cmd = "swaync-client -t -sw";
        desc = "Toggle the notification centre";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.B;
        cmd = "select-ghostty-shader";
        desc = "Pick a terminal shader";
        group = "Session";
      })
      # cliphist through rofi. Enter copies the entry and auto-pastes it
      # (Ctrl+V) into the focused window; in terminals and nvim that chord
      # means something else, so paste manually there.
      (keysLib.hypr.exec {
        on = on.super K.v;
        cmd = "$clipboard";
        desc = "Clipboard history";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.V;
        cmd = "yubikey-totp";
        desc = "YubiKey TOTP code";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.none K.printScreen;
        cmd = ''grim -g "$(slurp)" - | wl-copy'';
        desc = "Screenshot a region to the clipboard";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.P;
        cmd = ''grim -g "$(slurp)" - | wl-copy'';
        desc = "Screenshot a region to the clipboard";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.C;
        cmd = "hyprpicker -a -f hex";
        desc = "Pick a colour to the clipboard";
        group = "Session";
      })

      (keysLib.hypr.bind {
        on = on.super K.mouseLeft;
        dispatcher = "movewindow";
        desc = "Move window with the mouse";
        group = "Windows";
        flavor = "mouse";
      })
      (keysLib.hypr.bind {
        on = on.super K.mouseRight;
        dispatcher = "resizewindow";
        desc = "Resize window with the mouse";
        group = "Windows";
        flavor = "mouse";
      })
      (keysLib.hypr.bind {
        on = on.super K.w;
        dispatcher = "killactive";
        desc = "Close the focused window";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.t;
        dispatcher = "togglefloating";
        desc = "Toggle floating";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.super K.f;
        dispatcher = "fullscreen";
        arg = "1";
        desc = "Maximize (keep the bar)";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.F;
        dispatcher = "fullscreen";
        arg = "0";
        desc = "Fullscreen";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.super K.P;
        dispatcher = "pseudo";
        desc = "Toggle pseudo-tiling";
        group = "Windows";
      })
    ]
    ++ eachDirection (
      d:
      keysLib.hypr.bind {
        on = on.super d.key;
        dispatcher = "movefocus";
        arg = d.hypr;
        desc = "Focus ${d.word}";
        group = "Focus";
      }
    )
    ++ eachDirection (
      d:
      keysLib.hypr.bind {
        on = on.superShift d.key;
        dispatcher = "swapwindow";
        arg = d.hypr;
        desc = "Swap window ${d.word}";
        group = "Focus";
      }
    )
    ++ eachDirection (
      d:
      keysLib.hypr.bind {
        on = on.superAlt d.key;
        dispatcher = "resizeactive";
        arg =
          {
            h = "-40 0";
            l = "40 0";
            k = "0 -40";
            j = "0 40";
          }
          .${d.key.id};
        desc = "Resize ${d.word}";
        group = "Focus";
        flavor = "repeat";
      }
    )
    ++
      lib.concatMap
        (n: [
          (keysLib.hypr.bind {
            on = on.super K.${n};
            dispatcher = "workspace";
            arg = n;
            desc = "Go to workspace ${n}";
            group = "Workspaces";
          })
          (keysLib.hypr.bind {
            on = on.superShift K.${n};
            dispatcher = "movetoworkspace";
            arg = n;
            desc = "Move window to workspace ${n}";
            group = "Workspaces";
          })
        ])
        [
          "1"
          "2"
          "3"
          "4"
          "5"
        ]
    ++ [
      (keysLib.hypr.bind {
        on = on.superCtrl K.n;
        dispatcher = "workspace";
        arg = "e+1";
        desc = "Next workspace";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superCtrl K.p;
        dispatcher = "workspace";
        arg = "e-1";
        desc = "Previous workspace";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.wheelDown;
        dispatcher = "workspace";
        arg = "e+1";
        desc = "Next workspace";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.wheelUp;
        dispatcher = "workspace";
        arg = "e-1";
        desc = "Previous workspace";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.S;
        dispatcher = "togglespecialworkspace";
        arg = "magic";
        desc = "Toggle the scratchpad";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.S;
        dispatcher = "movetoworkspace";
        arg = "special:magic";
        desc = "Move window to the scratchpad";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.left;
        dispatcher = "focusmonitor";
        arg = "-1";
        desc = "Focus the previous monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.right;
        dispatcher = "focusmonitor";
        arg = "+1";
        desc = "Focus the next monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superCtrl K.left;
        dispatcher = "swapactiveworkspaces";
        arg = "current -1";
        desc = "Swap workspaces with the previous monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superCtrl K.right;
        dispatcher = "swapactiveworkspaces";
        arg = "current +1";
        desc = "Swap workspaces with the next monitor";
        group = "Workspaces";
      })

      # bindel: repeats while held and still fires on the lock screen.
      (keysLib.hypr.exec {
        on = on.none K.volumeUp;
        cmd = "volume up";
        desc = "Volume up";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.none K.volumeDown;
        cmd = "volume down";
        desc = "Volume down";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.none K.volumeMute;
        cmd = "volume mute";
        desc = "Mute";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.none K.brightnessUp;
        cmd = "brightness up";
        desc = "Screen brighter";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.none K.brightnessDown;
        cmd = "brightness down";
        desc = "Screen dimmer";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.none K.launchA;
        cmd = "kbdbacklight down";
        desc = "Keyboard backlight down";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.super K.launchA;
        cmd = "kbdbacklight up";
        desc = "Keyboard backlight up";
        group = "Media";
        flavor = "media";
      })
      (keysLib.hypr.exec {
        on = on.none K.kbdBrightnessDown;
        cmd = "kbdbacklight down";
        desc = "Keyboard backlight down";
        group = "Media";
        flavor = "media";
      })
    ];

    # Modal layers. Both are the same submap with a different dispatcher, so
    # they are generated rather than written twice.
    submaps = [
      (keysLib.hypr.nudgeSubmap {
        name = "move";
        enter = on.super K.M;
        dispatcher = "moveactive";
        desc = "Move window";
      })
      (keysLib.hypr.nudgeSubmap {
        name = "resize";
        enter = on.super K.R;
        dispatcher = "resizeactive";
        desc = "Resize window";
      })
    ];

    # The submaps' own entry keys, for the cheatsheet only — the bind lines
    # themselves are generated by the submap renderer.
    docs = [
      (doc {
        keys = "Super+M";
        desc = "Move mode: hjkl nudges, Shift finer, Ctrl coarser, Esc exits";
        group = "Modes";
      })
      (doc {
        keys = "Super+R";
        desc = "Resize mode: hjkl resizes, Shift finer, Ctrl coarser, Esc exits";
        group = "Modes";
      })
    ];
  };

  # ── tmux ────────────────────────────────────────────────────────────────
  tmux =
    let
      # tmux's six split bindings differ only in direction, size, and whether
      # the inherited ssh command keeps its ControlMaster. Splitting a pane
      # that is running ssh re-runs that ssh in the new pane; otherwise it
      # splits the shell at the same cwd.
      sshSplit =
        {
          direction,
          size ? null,
          shareConnection ? true,
        }:
        let
          flag = if direction == "down" then "-v" else "-h";
          sizeArg = lib.optionalString (size != null) " -l ${size}";
          # A second ssh over the same ControlMaster socket dies with the
          # first; -o ControlMaster=no gives the split its own connection.
          command =
            if shareConnection then ''"$cmd"'' else ''"''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}"'';
        in
        "run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E \"^ssh \" | head -n 1); "
        + "if [ -n \"$cmd\" ]; then tmux split-window ${flag} ${command}${sizeArg}; "
        + "else tmux split-window ${flag} -c \"#{pane_current_path}\"${sizeArg}; fi'";
    in
    {
      prefix = "Ctrl+b";

      binds = [
        (keysLib.tmux.bind {
          on = on.ctrl K.a;
          run = "send-prefix -2";
          desc = "Send the prefix through to the app";
          group = "Sessions";
        })
        (keysLib.tmux.bind {
          on = on.ctrl K.c;
          run = "new-session";
          desc = "New session";
          group = "Sessions";
        })
        (keysLib.tmux.bind {
          on = on.ctrl K.f;
          run = "command-prompt -p find-session 'switch-client -t %%'";
          desc = "Find a session";
          group = "Sessions";
        })
        (keysLib.tmux.bind {
          on = on.none K.backTab;
          run = "switch-client -l";
          desc = "Last session";
          group = "Sessions";
        })

        (keysLib.tmux.bind {
          on = on.none K.minus;
          run = sshSplit { direction = "down"; };
          desc = "Split down";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.shift K.minus;
          run = sshSplit {
            direction = "down";
            shareConnection = false;
          };
          desc = "Split down, new ssh connection";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.none K.underscore;
          run = sshSplit { direction = "right"; };
          desc = "Split right";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.none K.pipe;
          run = sshSplit {
            direction = "right";
            shareConnection = false;
          };
          desc = "Split right, new ssh connection";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.none K.equal;
          run = sshSplit {
            direction = "down";
            size = "20%";
          };
          desc = "Split down, 20% tall";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.shift K.equal;
          run = sshSplit {
            direction = "down";
            size = "20%";
            shareConnection = false;
          };
          desc = "Split down 20%, new ssh connection";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.none K.plus;
          run = sshSplit {
            direction = "right";
            size = "20%";
          };
          desc = "Split right, 20% wide";
          group = "Panes";
        })
      ]
      ++ eachDirection (
        d:
        keysLib.tmux.bind {
          on = on.none d.key;
          run = "select-pane -${d.tmux}";
          desc = "Focus ${d.word}";
          group = "Panes";
          repeat = true;
        }
      )
      ++ eachDirection (
        d:
        keysLib.tmux.bind {
          on = on.none d.upper;
          run = "resize-pane -${d.tmux} 5";
          desc = "Resize ${d.word}";
          group = "Panes";
          repeat = true;
        }
      )
      ++ [
        (keysLib.tmux.bind {
          on = on.none K.greater;
          run = "swap-pane -D";
          desc = "Swap pane forward";
          group = "Panes";
        })
        (keysLib.tmux.bind {
          on = on.none K.less;
          run = "swap-pane -U";
          desc = "Swap pane back";
          group = "Panes";
        })

        # n/p are freed so Ctrl-h / Ctrl-l can own window switching.
        (keysLib.tmux.unbind {
          key = K.n;
          group = "Windows";
        })
        (keysLib.tmux.unbind {
          key = K.p;
          group = "Windows";
        })
        (keysLib.tmux.bind {
          on = on.ctrl K.h;
          run = "previous-window";
          desc = "Previous window";
          group = "Windows";
          repeat = true;
        })
        (keysLib.tmux.bind {
          on = on.ctrl K.l;
          run = "next-window";
          desc = "Next window";
          group = "Windows";
          repeat = true;
        })
        (keysLib.tmux.bind {
          on = on.none K.tab;
          run = "last-window";
          desc = "Last window";
          group = "Windows";
        })

        (keysLib.tmux.bind {
          on = on.none K.v;
          run = "send-keys -X begin-selection";
          desc = "Start selecting";
          group = "Copy mode";
          table = "copy-mode-vi";
        })
        (keysLib.tmux.bind {
          on = on.ctrl K.v;
          run = "send-keys -X rectangle-toggle";
          desc = "Toggle block selection";
          group = "Copy mode";
          table = "copy-mode-vi";
        })
        (keysLib.tmux.bind {
          on = on.none K.y;
          run = "send-keys -X copy-selection-and-cancel";
          desc = "Yank the selection";
          group = "Copy mode";
          table = "copy-mode-vi";
        })
      ];
    };

  # ── zellij ──────────────────────────────────────────────────────────────
  zellij = rec {
    prefix = "Ctrl+b";

    # Ctrl-hjkl reaches the plugin, which forwards the key into nvim when nvim
    # has focus and moves zellij's own focus otherwise. The nvim half lives in
    # home/modules/neovim/navigation.nix.
    navigation = eachDirection (
      d:
      keysLib.zellij.bind {
        on = on.ctrl d.key;
        run = ''
          MessagePlugin "vim-zellij-navigator" {
              name "move_focus";
              payload "${lib.toLower d.word}";
          };'';
        desc = "Focus ${d.word} (passes through to nvim windows first)";
        group = "Panes, no prefix";
      }
    );

    enterPrefix = [
      (keysLib.zellij.bind {
        on = on.ctrl K.b;
        run = ''SwitchToMode "Tmux";'';
        desc = "Enter the prefix mode";
        group = "Modes";
      })
    ];

    # Straight to tab N with no Ctrl-b first, for jumping across many project
    # tabs fast. Alt+digit is free: it isn't one of the top-level-unbound
    # Ctrl-<key> mode-entry keys, and zellij's own defaults only use Alt for
    # letters/symbols (Alt-hjkl, Alt-+/-, ...), never Alt-digit.
    tabJump = map (
      n:
      keysLib.zellij.bind {
        on = on.alt K.${n};
        run = "GoToTab ${n};";
        desc = "Jump straight to tab ${n} (no prefix)";
        group = "Tabs, no prefix";
      }
    ) [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ];

    # Bindings inside the prefix. Zellij merges these with its own tmux-mode
    # defaults, which is why the extra keys further down are documented but
    # not declared.
    prefixed = [
      (keysLib.zellij.bind {
        on = on.ctrl K.b;
        run = [
          "Write 2;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Send a literal Ctrl-b to the shell";
        group = "Modes";
      })
      (keysLib.zellij.bind {
        on = on.none K.esc;
        run = ''SwitchToMode "Normal";'';
        desc = "Back to normal mode";
        group = "Modes";
      })

      (keysLib.zellij.bind {
        on = on.ctrl K.p;
        run = ''SwitchToMode "Pane";'';
        desc = "Pane mode (Esc to leave)";
        group = "Modes";
      })
      (keysLib.zellij.bind {
        on = on.ctrl K.n;
        run = ''SwitchToMode "Resize";'';
        desc = "Resize mode, hjkl grows and HJKL shrinks (Esc to leave)";
        group = "Modes";
      })
      (keysLib.zellij.bind {
        on = on.ctrl K.t;
        run = ''SwitchToMode "Tab";'';
        desc = "Tab mode, x closes the tab (Esc to leave)";
        group = "Modes";
      })
      (keysLib.zellij.bind {
        on = on.ctrl K.o;
        run = ''SwitchToMode "Session";'';
        desc = "Session mode (Esc to leave)";
        group = "Modes";
      })

      (keysLib.zellij.bind {
        on = [
          (on.none K.minus)
          (on.none K.equal)
        ];
        run = [
          ''NewPane "Down";''
          ''SwitchToMode "Normal";''
        ];
        desc = "Split down";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = [
          (on.none K.pipe)
          (on.none K.underscore)
          (on.none K.plus)
        ];
        run = [
          ''NewPane "Right";''
          ''SwitchToMode "Normal";''
        ];
        desc = "Split right";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.s;
        run = [
          ''
            Run "${cmd.zjSshSplit}" "right" {
                floating true
                close_on_exit true
                name "ssh"
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Pick an ssh host and split right into it";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.S;
        run = [
          ''
            Run "${cmd.zjSshSplit}" "down" {
                floating true
                close_on_exit true
                name "ssh"
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Pick an ssh host and split down into it";
        group = "Panes";
      })
    ]
    ++ eachDirection (
      d:
      keysLib.zellij.bind {
        on = on.none d.key;
        run = ''MoveFocus "${d.zellij}";'';
        desc = "Focus ${d.word}";
        group = "Panes";
      }
    )
    ++ eachDirection (
      d:
      keysLib.zellij.bind {
        on = on.none d.upper;
        run = ''Resize "Increase ${d.zellij}";'';
        desc = "Resize ${d.word}";
        group = "Panes";
      }
    )
    ++ [
      (keysLib.zellij.bind {
        on = on.none K.less;
        run = "MovePaneBackwards;";
        desc = "Move pane back";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.greater;
        run = "MovePane;";
        desc = "Move pane forward";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.m;
        run = ''SwitchToMode "Move";'';
        desc = "Move mode";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.r;
        run = [
          ''SwitchToMode "RenamePane";''
          "PaneNameInput 0;"
        ];
        desc = "Rename pane";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = [
          (on.none K.b)
          (on.none K.bang)
        ];
        run = [
          "BreakPane;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Break pane out to its own tab";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.braceOpen;
        run = [
          "BreakPaneLeft;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Break pane to the tab on the left";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.braceClose;
        run = [
          "BreakPaneRight;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Break pane to the tab on the right";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.g;
        run = "TogglePaneInGroup;";
        desc = "Add or remove this pane from the group";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.G;
        run = "ToggleGroupMarking;";
        desc = "Toggle group marking";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.w;
        run = [
          "ToggleFloatingPanes;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Toggle the floating layer";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.e;
        run = [
          "TogglePaneEmbedOrFloating;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Float or tile this pane";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.i;
        run = [
          "TogglePanePinned;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Pin a floating pane on top";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.t;
        run = [
          ''NewPane "stacked";''
          ''SwitchToMode "Normal";''
        ];
        desc = "New stacked pane";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.u;
        run = "NextSwapLayout;";
        desc = "Next swap layout";
        group = "Panes";
      })
      (keysLib.zellij.bind {
        on = on.none K.U;
        run = "PreviousSwapLayout;";
        desc = "Previous swap layout";
        group = "Panes";
      })

      (keysLib.zellij.bind {
        on = on.none K.c;
        run = [
          "NewTab;"
          ''SwitchToMode "Normal";''
        ];
        desc = "New tab";
        group = "Tabs";
      })
      (keysLib.zellij.bind {
        on = on.none K.comma;
        run = [
          ''SwitchToMode "RenameTab";''
          "TabNameInput 0;"
        ];
        desc = "Rename tab";
        group = "Tabs";
      })
      (keysLib.zellij.bind {
        on = on.ctrl K.h;
        run = "GoToPreviousTab;";
        desc = "Previous tab";
        group = "Tabs";
      })
      (keysLib.zellij.bind {
        on = on.ctrl K.l;
        run = "GoToNextTab;";
        desc = "Next tab";
        group = "Tabs";
      })
      (keysLib.zellij.bind {
        on = on.none K.tab;
        run = [
          "ToggleTab;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Last tab";
        group = "Tabs";
      })
      (keysLib.zellij.bind {
        on = on.none K.semicolon;
        run = ''MoveTab "Left";'';
        desc = "Move tab left";
        group = "Tabs";
      })
      (keysLib.zellij.bind {
        on = on.none K.period;
        run = ''MoveTab "Right";'';
        desc = "Move tab right";
        group = "Tabs";
      })
    ]
    ++
      map
        (
          n:
          keysLib.zellij.bind {
            on = on.none K.${n};
            run = [
              "GoToTab ${n};"
              ''SwitchToMode "Normal";''
            ];
            desc = "Go to tab ${n}";
            group = "Tabs";
          }
        )
        [
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
          "7"
          "8"
          "9"
        ]
    ++ [
      (keysLib.zellij.bind {
        on = on.none K.E;
        run = [
          "EditScrollback;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Open the whole scrollback in nvim";
        group = "Session & tools";
      })
      (keysLib.zellij.bind {
        on = on.none K.f;
        run = [
          ''
            LaunchOrFocusPlugin "session-manager" {
                floating true
                move_to_focused_tab true
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Session manager";
        group = "Session & tools";
      })
      (keysLib.zellij.bind {
        on = on.none K.P;
        run = [
          ''
            LaunchOrFocusPlugin "plugin-manager" {
                floating true
                move_to_focused_tab true
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Plugin manager";
        group = "Session & tools";
      })
      (keysLib.zellij.bind {
        on = on.none K.slash;
        run = [
          ''
            LaunchOrFocusPlugin "filepicker" {
                floating true
                move_to_focused_tab true
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "File picker";
        group = "Session & tools";
      })
      (keysLib.zellij.bind {
        on = on.none K.x;
        run = [
          ''
            Run "${cmd.zjClaudeJump}" {
                floating true
                close_on_exit true
                name "claude-jump"
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Jump to a running Claude Code pane";
        group = "Session & tools";
      })
    ];

    scroll = [
      (keysLib.zellij.bind {
        on = on.none K.y;
        run = [
          "EditScrollback;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Hand the scrollback to nvim (tmux muscle memory)";
        group = "Scrollback";
      })
    ];

    search = [
      (keysLib.zellij.bind {
        on = [
          (on.none K.y)
          (on.none K.e)
        ];
        run = [
          "EditScrollback;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Hand the scrollback to nvim";
        group = "Scrollback";
      })
    ];

    # Zellij's own defaults, kept in the cheatsheet because they are half of
    # what a user reaches for. Not declared above: zellij already binds them.
    docs = [
      (doc {
        keys = "${prefix} d";
        desc = "Detach from the session";
        group = "Session & tools";
      })
      (doc {
        keys = "${prefix} [";
        desc = "Scroll mode";
        group = "Session & tools";
      })
      (doc {
        keys = "${prefix} o";
        desc = "Next pane";
        group = "Panes";
      })
      (doc {
        keys = "${prefix} x";
        desc = "Close pane";
        group = "Panes";
      })
      (doc {
        keys = "${prefix} z";
        desc = "Zoom the pane (fullscreen)";
        group = "Panes";
      })
      (doc {
        keys = "${prefix} n / p";
        desc = "Next / previous tab";
        group = "Tabs";
      })
      (doc {
        keys = "${prefix} Space";
        desc = "Next swap layout";
        group = "Panes";
      })
      (doc {
        keys = "Alt+n";
        desc = "New pane (no prefix)";
        group = "No prefix";
      })
      (doc {
        keys = "Alt+f";
        desc = "Toggle floating (no prefix)";
        group = "No prefix";
      })
      (doc {
        keys = "Alt+h/j/k/l";
        desc = "Focus pane or tab (no prefix)";
        group = "No prefix";
      })
      (doc {
        keys = "Alt++ / Alt+-";
        desc = "Resize pane (no prefix)";
        group = "No prefix";
      })
      (doc {
        keys = "Alt+[ / Alt+]";
        desc = "Previous / next swap layout (no prefix)";
        group = "No prefix";
      })
      (doc {
        keys = "Alt+i / Alt+o";
        desc = "Move tab left / right (no prefix)";
        group = "No prefix";
      })
      (doc {
        keys = "Ctrl+q";
        desc = "Quit zellij";
        group = "No prefix";
      })
      # Zellij has no keyboard select-and-yank: Copy only copies the mouse
      # selection. These are the ways that do work.
      (doc {
        keys = "drag the mouse";
        desc = "Selects and copies on release, no mode needed";
        group = "Copying";
      })
      (doc {
        keys = "${prefix} [ then y or e";
        desc = "Scroll mode, then the whole buffer in nvim — select and y there";
        group = "Copying";
      })
      (doc {
        keys = "${prefix} [ then s";
        desc = "Search the buffer (n / p between hits), then y or e";
        group = "Copying";
      })
      (doc {
        keys = "${prefix} E";
        desc = "Straight from a normal pane into nvim";
        group = "Copying";
      })
    ];
  };

  # ── ghostty ─────────────────────────────────────────────────────────────
  ghostty = {
    binds = [
      (keysLib.ghostty.bind {
        on = mkChord [
          M.ctrl
          M.shift
        ] K.equal;
        action = "increase_font_size:1";
        desc = "Bigger font";
        group = "Font";
      })
      (keysLib.ghostty.bind {
        on = mkChord [
          M.ctrl
          M.shift
        ] K.minus;
        action = "decrease_font_size:1";
        desc = "Smaller font";
        group = "Font";
      })
      (keysLib.ghostty.bind {
        on = on.ctrl K.equal;
        action = "reset_font_size";
        desc = "Reset the font size";
        group = "Font";
      })
      (keysLib.ghostty.bind {
        on = mkChord [
          M.ctrl
          M.shift
        ] K.c;
        action = "copy_to_clipboard";
        desc = "Copy";
        group = "Clipboard";
      })
      (keysLib.ghostty.bind {
        on = mkChord [
          M.ctrl
          M.shift
        ] K.v;
        action = "paste_from_clipboard";
        desc = "Paste";
        group = "Clipboard";
      })
      (keysLib.ghostty.bind {
        on = mkChord [
          M.ctrl
          M.shift
        ] K.r;
        action = "reload_config";
        desc = "Reload the config";
        group = "Terminal";
      })
    ];
  };

  # ── zsh line editor ─────────────────────────────────────────────────────
  # Documentation only, and the one place in this file that is not the source
  # of truth: these bindkeys stay in home/modules/shell/zsh.nix because each
  # one sits next to the `autoload`/`zle -N` that defines its widget, and two
  # of them only apply inside a `command -v` guard. Change one there and here.
  zsh = {
    docs = [
      (doc {
        keys = "Ctrl+n";
        desc = "navi widget — insert a command from the cheatsheets";
        group = "Line editor";
      })
      (doc {
        keys = "Ctrl+g";
        desc = "Edit the current command line in nvim";
        group = "Line editor";
      })
      (doc {
        keys = "Ctrl+Space";
        desc = "Accept the autosuggestion";
        group = "Line editor";
      })
      (doc {
        keys = "↑ / ↓";
        desc = "History search on the prefix already typed";
        group = "Line editor";
      })
    ];
  };
}
