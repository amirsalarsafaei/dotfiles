{
  lib,
  keysLib,
  cmd,
}:
let
  inherit (keysLib)
    K
    on
    doc
    ;

  directions = {
    h = {
      key = K.h;
      upper = K.H;
      arrow = K.left;
      zellij = "Left";
      tmux = "L";
      word = "left";
    };
    j = {
      key = K.j;
      upper = K.J;
      arrow = K.down;
      zellij = "Down";
      tmux = "D";
      word = "down";
    };
    k = {
      key = K.k;
      upper = K.K;
      arrow = K.up;
      zellij = "Up";
      tmux = "U";
      word = "up";
    };
    l = {
      key = K.l;
      upper = K.L;
      arrow = K.right;
      zellij = "Right";
      tmux = "R";
      word = "right";
    };
  };

  zbind = keysLib.zellij.bind;

  eachDirection =
    f:
    map (name: f directions.${name}) [
      "h"
      "j"
      "k"
      "l"
    ];

  tabDigits = [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
  ];

  goToTab =
    group:
    map (
      n:
      zbind {
        on = on.none K.${n};
        run = [
          "GoToTab ${n};"
          ''SwitchToMode "Normal";''
        ];
        desc = "Go to tab ${n}";
        inherit group;
      }
    ) tabDigits;

  editScrollback =
    group:
    zbind {
      on = [
        (on.none K.e)
      ];
      run = [
        "EditScrollback;"
        ''SwitchToMode "Normal";''
      ];
      desc = "Hand the scrollback to nvim";
      inherit group;
    };

  closePane =
    group:
    zbind {
      on = on.none K.x;
      run = [
        "CloseFocus;"
        ''SwitchToMode "Normal";''
      ];
      desc = "Close pane";
      inherit group;
    };
in
{
  hyprland = {
    binds = [
      (keysLib.hypr.exec {
        on = on.super K.enter;
        cmd = cmd.terminal;
        desc = "Open a terminal";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.space;
        cmd = cmd.menu;
        desc = "App launcher";
        group = "Session";
      })
      (keysLib.hypr.bind {
        on = on.super K.tab;
        dsp = ''function() hl.plugin.hyprtasking.toggle("cursor") end'';
        desc = "Workspace overview";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.d;
        cmd = cmd.sidebarToggle;
        desc = "Toggle the sidebar dashboard";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.g;
        cmd = cmd.widgetsToggle;
        desc = "Toggle the desktop widget board";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.c;
        cmd = cmd.agentsPick;
        desc = "Pick a Claude Code agent in the sidebar";
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
        dsp = "hl.dsp.exit()";
        desc = "Quit Hyprland";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.b;
        cmd = cmd.barToggle;
        desc = "Show or hide the bar";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.u;
        cmd = cmd.skyToggle;
        desc = "Wallpaper: flip the sky (dusk by day, midday by night), or back to the real sky";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.y;
        cmd = cmd.lyricsToggle;
        desc = "Wallpaper: float the synced lyrics over the sky";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.g;
        cmd = cmd.focusMode;
        desc = "Focus mode: no gaps, no bar";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.N;
        cmd = "swaync-client -t -sw";
        desc = "Toggle the notification centre";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.a;
        cmd = cmd.agendaShow;
        desc = "Show today's agenda";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.a;
        cmd = cmd.agendaDone;
        desc = "Mark the current agenda event done";
        group = "Session";
      })
      (keysLib.hypr.exec {
        on = on.super K.v;
        cmd = cmd.clipboard;
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
        dsp = "hl.dsp.window.drag()";
        desc = "Move window with the mouse";
        group = "Windows";
        flavor = "mouse";
      })
      (keysLib.hypr.bind {
        on = on.super K.mouseRight;
        dsp = "hl.dsp.window.resize()";
        desc = "Resize window with the mouse";
        group = "Windows";
        flavor = "mouse";
      })
      (keysLib.hypr.bind {
        on = on.super K.w;
        dsp = "hl.dsp.window.close()";
        desc = "Close the focused window";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.t;
        dsp = ''hl.dsp.window.float({ action = "toggle" })'';
        desc = "Toggle floating";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.super K.f;
        dsp = ''hl.dsp.window.fullscreen({ mode = "maximized" })'';
        desc = "Maximize (keep the bar)";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.F;
        dsp = ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'';
        desc = "Fullscreen";
        group = "Windows";
      })
      (keysLib.hypr.bind {
        on = on.super K.P;
        dsp = "hl.dsp.window.pseudo()";
        desc = "Toggle pseudo-tiling";
        group = "Windows";
      })
    ]
    ++ eachDirection (
      d:
      keysLib.hypr.bind {
        on = on.super d.key;
        dsp = ''hl.dsp.focus({ direction = "${d.word}" })'';
        desc = "Focus ${d.word}";
        group = "Focus";
      }
    )
    ++ eachDirection (
      d:
      keysLib.hypr.bind {
        on = on.superShift d.key;
        dsp = ''hl.dsp.window.swap({ direction = "${d.word}" })'';
        desc = "Swap window ${d.word}";
        group = "Focus";
      }
    )
    ++ eachDirection (
      d:
      keysLib.hypr.bind {
        on = on.superAlt d.key;
        dsp = "hl.dsp.window.resize({ ${
          {
            h = "x = -40, y = 0";
            l = "x = 40, y = 0";
            k = "x = 0, y = -40";
            j = "x = 0, y = 40";
          }
          .${d.key.id}
        }, relative = true })";
        desc = "Resize ${d.word}";
        group = "Focus";
        flavor = "repeat";
      }
    )
    ++
      lib.concatMap
        (n: [
          (keysLib.hypr.exec {
            on = on.super K.${n};
            cmd = "${cmd.workspaceSplit} focus ${n}";
            desc = "Go to workspace ${n} on this monitor";
            group = "Workspaces";
          })
          (keysLib.hypr.exec {
            on = on.superShift K.${n};
            cmd = "${cmd.workspaceSplit} move ${n}";
            desc = "Move window to workspace ${n} on this monitor";
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
        dsp = ''hl.dsp.focus({ workspace = "m+1" })'';
        desc = "Next workspace on this monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superCtrl K.p;
        dsp = ''hl.dsp.focus({ workspace = "m-1" })'';
        desc = "Previous workspace on this monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.wheelDown;
        dsp = ''hl.dsp.focus({ workspace = "m+1" })'';
        desc = "Next workspace on this monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.wheelUp;
        dsp = ''hl.dsp.focus({ workspace = "m-1" })'';
        desc = "Previous workspace on this monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.S;
        dsp = ''hl.dsp.workspace.toggle_special("magic")'';
        desc = "Toggle the scratchpad";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.S;
        dsp = ''hl.dsp.window.move({ workspace = "special:magic" })'';
        desc = "Move window to the scratchpad";
        group = "Workspaces";
      })
      (keysLib.hypr.exec {
        on = on.super K.o;
        cmd = cmd.spotifySpace;
        desc = "Toggle the Spotify space (launches Spotify if needed)";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.left;
        dsp = ''hl.dsp.focus({ monitor = "-1" })'';
        desc = "Focus the previous monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.super K.right;
        dsp = ''hl.dsp.focus({ monitor = "+1" })'';
        desc = "Focus the next monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.left;
        dsp = ''hl.dsp.window.move({ monitor = "-1" })'';
        desc = "Move window to the previous monitor";
        group = "Monitors";
      })
      (keysLib.hypr.bind {
        on = on.superShift K.right;
        dsp = ''hl.dsp.window.move({ monitor = "+1" })'';
        desc = "Move window to the next monitor";
        group = "Monitors";
      })
      (keysLib.hypr.bind {
        on = on.superAlt K.left;
        dsp = ''hl.dsp.workspace.move({ monitor = "-1" })'';
        desc = "Move workspace to the previous monitor";
        group = "Monitors";
      })
      (keysLib.hypr.bind {
        on = on.superAlt K.right;
        dsp = ''hl.dsp.workspace.move({ monitor = "+1" })'';
        desc = "Move workspace to the next monitor";
        group = "Monitors";
      })
      (keysLib.hypr.exec {
        on = on.superShift K.D;
        cmd = cmd.displayMenu;
        desc = "Display layout menu";
        group = "Monitors";
      })
      (keysLib.hypr.exec {
        on = on.none K.lidClose;
        cmd = "${cmd.displayLid} sync";
        desc = "Turn the laptop panel off while an external monitor is connected";
        group = "Monitors";
        flavor = "switch";
      })
      (keysLib.hypr.exec {
        on = on.none K.lidOpen;
        cmd = "${cmd.displayLid} open";
        desc = "Turn the laptop panel back on";
        group = "Monitors";
        flavor = "switch";
      })
      (keysLib.hypr.bind {
        on = on.superCtrl K.left;
        dsp = ''hl.dsp.workspace.swap_monitors({ monitor1 = "current", monitor2 = "-1" })'';
        desc = "Swap workspaces with the previous monitor";
        group = "Workspaces";
      })
      (keysLib.hypr.bind {
        on = on.superCtrl K.right;
        dsp = ''hl.dsp.workspace.swap_monitors({ monitor1 = "current", monitor2 = "+1" })'';
        desc = "Swap workspaces with the next monitor";
        group = "Workspaces";
      })

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
      (keysLib.hypr.exec {
        on = on.superShift K.o;
        cmd = "oled-toggle";
        desc = "Toggle internal OLED display";
        group = "Media";
      })
    ];

    submaps = [
      (keysLib.hypr.nudgeSubmap {
        name = "move";
        enter = on.super K.M;
        action = "move";
        desc = "Move window";
      })
      (keysLib.hypr.nudgeSubmap {
        name = "resize";
        enter = on.super K.R;
        action = "resize";
        desc = "Resize window";
      })
    ];

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

  tmux =
    let
      sshSplit =
        {
          direction,
          size ? null,
          shareConnection ? true,
        }:
        let
          flag = if direction == "down" then "-v" else "-h";
          sizeArg = lib.optionalString (size != null) " -l ${size}";
          command =
            if shareConnection then ''"$cmd"'' else ''"''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}"'';
        in
        "run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E \"^ssh \" | head -n 1); "
        + "if [ -n \"$cmd\" ]; then tmux split-window ${flag} ${command}${sizeArg}; "
        + "else tmux split-window ${flag} -c \"#{pane_current_path}\"${sizeArg}; fi'";
    in
    {
      prefix = "Ctrl+Space";

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

  zellij = rec {
    prefix = "Ctrl+Space";

    navigation = eachDirection (
      d:
      zbind {
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

    prefixEnter = [
      (zbind {
        on = on.ctrl K.space;
        run = ''SwitchToMode "Tmux";'';
        desc = "Prefix — everything else is behind this key";
        group = "Modes";
      })
    ];

    leaveMode = [
      (zbind {
        on = [
          (on.none K.enter)
          (on.none K.esc)
        ];
        run = ''SwitchToMode "Normal";'';
        desc = "Back to normal mode";
        group = "Modes";
      })
    ];

    prefixed = [
      (zbind {
        on = on.ctrl K.space;
        run = [
          "Write 0;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Send a literal Ctrl+Space to the app";
        group = "Modes";
      })
      (zbind {
        on = on.ctrl K.p;
        run = ''SwitchToMode "Pane";'';
        desc = "Pane mode (Esc to leave)";
        group = "Modes";
      })
      (zbind {
        on = on.ctrl K.n;
        run = ''SwitchToMode "Resize";'';
        desc = "Resize mode, hjkl grows and HJKL shrinks (Esc to leave)";
        group = "Modes";
      })
      (zbind {
        on = on.ctrl K.t;
        run = ''SwitchToMode "Tab";'';
        desc = "Tab mode, x closes the tab (Esc to leave)";
        group = "Modes";
      })
      (zbind {
        on = on.ctrl K.o;
        run = ''SwitchToMode "Session";'';
        desc = "Session mode (Esc to leave)";
        group = "Modes";
      })
      (zbind {
        on = on.none K.bracketOpen;
        run = ''SwitchToMode "Scroll";'';
        desc = "Scroll mode";
        group = "Modes";
      })
      (zbind {
        on = on.none K.m;
        run = ''SwitchToMode "Move";'';
        desc = "Move mode";
        group = "Modes";
      })

      (zbind {
        on = [
          (on.none K.dquote)
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
      (zbind {
        on = [
          (on.none K.percent)
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
    ]
    ++ eachDirection (
      d:
      zbind {
        on = on.none d.key;
        run = ''MoveFocus "${d.zellij}";'';
        desc = "Focus ${d.word}";
        group = "Panes";
      }
    )
    ++ eachDirection (
      d:
      zbind {
        on = on.none d.arrow;
        run = [
          ''MoveFocus "${d.zellij}";''
          ''SwitchToMode "Normal";''
        ];
        desc = "Focus ${d.word} and leave the prefix";
        group = "Panes";
      }
    )
    ++ eachDirection (
      d:
      zbind {
        on = on.none d.upper;
        run = ''Resize "Increase ${d.zellij}";'';
        desc = "Resize ${d.word}";
        group = "Panes";
      }
    )
    ++ [
      (zbind {
        on = on.none K.o;
        run = "FocusNextPane;";
        desc = "Next pane";
        group = "Panes";
      })
      (closePane "Panes")
      (zbind {
        on = on.none K.z;
        run = [
          "ToggleFocusFullscreen;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Zoom the pane (fullscreen)";
        group = "Panes";
      })
      (zbind {
        on = on.none K.less;
        run = "MovePaneBackwards;";
        desc = "Move pane back";
        group = "Panes";
      })
      (zbind {
        on = on.none K.greater;
        run = "MovePane;";
        desc = "Move pane forward";
        group = "Panes";
      })
      (zbind {
        on = on.none K.r;
        run = [
          ''SwitchToMode "RenamePane";''
          "PaneNameInput 0;"
        ];
        desc = "Rename pane";
        group = "Panes";
      })

      (zbind {
        on = on.none K.c;
        run = [
          "NewTab;"
          ''SwitchToMode "Normal";''
        ];
        desc = "New tab";
        group = "Tabs";
      })
      (zbind {
        on = on.none K.comma;
        run = [
          ''SwitchToMode "RenameTab";''
          "TabNameInput 0;"
        ];
        desc = "Rename tab";
        group = "Tabs";
      })
      (zbind {
        on = [
          (on.ctrl K.h)
          (on.none K.p)
        ];
        run = "GoToPreviousTab;";
        desc = "Previous tab";
        group = "Tabs";
      })
      (zbind {
        on = [
          (on.ctrl K.l)
          (on.none K.n)
        ];
        run = "GoToNextTab;";
        desc = "Next tab";
        group = "Tabs";
      })
      (zbind {
        on = on.none K.tab;
        run = [
          "ToggleTab;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Last tab";
        group = "Tabs";
      })
      (zbind {
        on = on.none K.semicolon;
        run = ''MoveTab "Left";'';
        desc = "Move tab left";
        group = "Tabs";
      })
      (zbind {
        on = on.none K.period;
        run = ''MoveTab "Right";'';
        desc = "Move tab right";
        group = "Tabs";
      })
    ]
    ++ goToTab "Tabs"
    ++ [
      (zbind {
        on = on.none K.d;
        run = "Detach;";
        desc = "Detach from the session";
        group = "Session & tools";
      })
      (zbind {
        on = on.none K.Q;
        run = "Quit;";
        desc = "Quit zellij";
        group = "Session & tools";
      })
      (zbind {
        on = on.none K.E;
        run = [
          "EditScrollback;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Open the whole scrollback in nvim";
        group = "Session & tools";
      })
      (zbind {
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
      (zbind {
        on = on.none K.C;
        run = [
          ''
            Run "${cmd.agentsPick}" {
                floating true
                close_on_exit true
                name "agents"
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Pick a Claude Code agent in the sidebar";
        group = "Session & tools";
      })
      (zbind {
        on = on.none K.y;
        run = [
          ''
            LaunchOrFocusPlugin "harpoon" {
                floating true
                move_to_focused_tab true
            };''
          ''SwitchToMode "Normal";''
        ];
        desc = "Harpoon — pin panes, jump straight back to one";
        group = "Session & tools";
      })
    ];

    paneMode =
      eachDirection (
        d:
        zbind {
          on = [
            (on.none d.key)
            (on.none d.arrow)
          ];
          run = ''MoveFocus "${d.zellij}";'';
          desc = "Focus ${d.word}";
          group = "Pane mode";
        }
      )
      ++ [
        (zbind {
          on = on.none K.p;
          run = "SwitchFocus;";
          desc = "Focus the previously focused pane";
          group = "Pane mode";
        })
        (zbind {
          on = on.none K.n;
          run = [
            "NewPane;"
            ''SwitchToMode "Normal";''
          ];
          desc = "New pane";
          group = "Pane mode";
        })
        (zbind {
          on = on.none K.d;
          run = [
            ''NewPane "Down";''
            ''SwitchToMode "Normal";''
          ];
          desc = "Split down";
          group = "Pane mode";
        })
        (zbind {
          on = on.none K.r;
          run = [
            ''NewPane "Right";''
            ''SwitchToMode "Normal";''
          ];
          desc = "Split right";
          group = "Pane mode";
        })
        (closePane "Pane mode")
        (zbind {
          on = on.none K.f;
          run = [
            "ToggleFocusFullscreen;"
            ''SwitchToMode "Normal";''
          ];
          desc = "Zoom the pane (fullscreen)";
          group = "Pane mode";
        })
        (zbind {
          on = on.none K.z;
          run = [
            "TogglePaneFrames;"
            ''SwitchToMode "Normal";''
          ];
          desc = "Toggle pane frames";
          group = "Pane mode";
        })
        (zbind {
          on = on.none K.c;
          run = [
            ''SwitchToMode "RenamePane";''
            "PaneNameInput 0;"
          ];
          desc = "Rename pane";
          group = "Pane mode";
        })
      ];

    tabMode = [
      (zbind {
        on = on.none K.r;
        run = [
          ''SwitchToMode "RenameTab";''
          "TabNameInput 0;"
        ];
        desc = "Rename tab";
        group = "Tab mode";
      })
      (zbind {
        on = [
          (on.none K.h)
          (on.none K.left)
          (on.none K.k)
          (on.none K.up)
        ];
        run = "GoToPreviousTab;";
        desc = "Previous tab";
        group = "Tab mode";
      })
      (zbind {
        on = [
          (on.none K.l)
          (on.none K.right)
          (on.none K.j)
          (on.none K.down)
        ];
        run = "GoToNextTab;";
        desc = "Next tab";
        group = "Tab mode";
      })
      (zbind {
        on = on.none K.n;
        run = [
          "NewTab;"
          ''SwitchToMode "Normal";''
        ];
        desc = "New tab";
        group = "Tab mode";
      })
      (zbind {
        on = on.none K.x;
        run = [
          "CloseTab;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Close tab";
        group = "Tab mode";
      })
      (zbind {
        on = on.none K.tab;
        run = "ToggleTab;";
        desc = "Last tab";
        group = "Tab mode";
      })
    ]
    ++ goToTab "Tab mode";

    resizeMode =
      eachDirection (
        d:
        zbind {
          on = [
            (on.none d.key)
            (on.none d.arrow)
          ];
          run = ''Resize "Increase ${d.zellij}";'';
          desc = "Grow ${d.word}";
          group = "Resize mode";
        }
      )
      ++ eachDirection (
        d:
        zbind {
          on = on.none d.upper;
          run = ''Resize "Decrease ${d.zellij}";'';
          desc = "Shrink ${d.word}";
          group = "Resize mode";
        }
      )
      ++ [
        (zbind {
          on = [
            (on.none K.equal)
            (on.none K.plus)
          ];
          run = ''Resize "Increase";'';
          desc = "Grow the pane";
          group = "Resize mode";
        })
        (zbind {
          on = on.none K.minus;
          run = ''Resize "Decrease";'';
          desc = "Shrink the pane";
          group = "Resize mode";
        })
      ];

    moveMode =
      eachDirection (
        d:
        zbind {
          on = [
            (on.none d.key)
            (on.none d.arrow)
          ];
          run = ''MovePane "${d.zellij}";'';
          desc = "Move the pane ${d.word}";
          group = "Move mode";
        }
      )
      ++ [
        (zbind {
          on = [
            (on.none K.n)
            (on.none K.tab)
          ];
          run = "MovePane;";
          desc = "Move the pane forward";
          group = "Move mode";
        })
        (zbind {
          on = on.none K.p;
          run = "MovePaneBackwards;";
          desc = "Move the pane back";
          group = "Move mode";
        })
      ];

    scrollMotions = [
      (zbind {
        on = on.ctrl K.c;
        run = [
          "ScrollToBottom;"
          ''SwitchToMode "Normal";''
        ];
        desc = "Jump to the bottom and leave";
        group = "Scrollback";
      })
      (zbind {
        on = [
          (on.none K.j)
          (on.none K.down)
        ];
        run = "ScrollDown;";
        desc = "Down a line";
        group = "Scrollback";
      })
      (zbind {
        on = [
          (on.none K.k)
          (on.none K.up)
        ];
        run = "ScrollUp;";
        desc = "Up a line";
        group = "Scrollback";
      })
      (zbind {
        on = [
          (on.ctrl K.f)
          (on.none K.pageDown)
          (on.none K.right)
          (on.none K.l)
        ];
        run = "PageScrollDown;";
        desc = "Down a page";
        group = "Scrollback";
      })
      (zbind {
        on = [
          (on.ctrl K.b)
          (on.none K.pageUp)
          (on.none K.left)
          (on.none K.h)
        ];
        run = "PageScrollUp;";
        desc = "Up a page";
        group = "Scrollback";
      })
      (zbind {
        on = on.none K.d;
        run = "HalfPageScrollDown;";
        desc = "Down half a page";
        group = "Scrollback";
      })
      (zbind {
        on = on.none K.u;
        run = "HalfPageScrollUp;";
        desc = "Up half a page";
        group = "Scrollback";
      })
    ];

    scrollMode = scrollMotions ++ [
      (editScrollback "Scrollback")
      (zbind {
        on = on.none K.s;
        run = [
          ''SwitchToMode "EnterSearch";''
          "SearchInput 0;"
        ];
        desc = "Search the buffer";
        group = "Scrollback";
      })
    ];

    searchMode = scrollMotions ++ [
      (editScrollback "Search")
      (zbind {
        on = on.none K.n;
        run = ''Search "down";'';
        desc = "Next hit";
        group = "Search";
      })
      (zbind {
        on = on.none K.p;
        run = ''Search "up";'';
        desc = "Previous hit";
        group = "Search";
      })
      (zbind {
        on = on.none K.c;
        run = ''SearchToggleOption "CaseSensitivity";'';
        desc = "Toggle case sensitivity";
        group = "Search";
      })
      (zbind {
        on = on.none K.w;
        run = ''SearchToggleOption "Wrap";'';
        desc = "Toggle wrap-around";
        group = "Search";
      })
      (zbind {
        on = on.none K.o;
        run = ''SearchToggleOption "WholeWord";'';
        desc = "Toggle whole-word matching";
        group = "Search";
      })
    ];

    enterSearchMode = [
      (zbind {
        on = [
          (on.ctrl K.c)
          (on.none K.esc)
        ];
        run = ''SwitchToMode "Scroll";'';
        desc = "Cancel the search";
        group = "Search";
      })
      (zbind {
        on = on.none K.enter;
        run = ''SwitchToMode "Search";'';
        desc = "Run the search";
        group = "Search";
      })
    ];

    renameTabMode = [
      (zbind {
        on = on.ctrl K.c;
        run = ''SwitchToMode "Normal";'';
        desc = "Keep the new name";
        group = "Tabs";
      })
      (zbind {
        on = on.none K.esc;
        run = [
          "UndoRenameTab;"
          ''SwitchToMode "Tab";''
        ];
        desc = "Cancel the rename";
        group = "Tabs";
      })
    ];

    renamePaneMode = [
      (zbind {
        on = on.ctrl K.c;
        run = ''SwitchToMode "Normal";'';
        desc = "Keep the new name";
        group = "Panes";
      })
      (zbind {
        on = on.none K.esc;
        run = [
          "UndoRenamePane;"
          ''SwitchToMode "Pane";''
        ];
        desc = "Cancel the rename";
        group = "Panes";
      })
    ];

    sessionMode =
      let
        plugin = key: name: desc: {
          inherit key name desc;
        };
      in
      [
        (zbind {
          on = on.none K.d;
          run = "Detach;";
          desc = "Detach from the session";
          group = "Session mode";
        })
      ]
      ++
        map
          (
            p:
            zbind {
              on = on.none p.key;
              run = [
                ''
                  LaunchOrFocusPlugin "${p.name}" {
                      floating true
                      move_to_focused_tab true
                  };''
                ''SwitchToMode "Normal";''
              ];
              inherit (p) desc;
              group = "Session mode";
            }
          )
          [
            (plugin K.w "session-manager" "Session manager")
            (plugin K.c "configuration" "Zellij's own configuration screen")
            (plugin K.a "zellij:about" "About zellij")
            (plugin K.s "zellij:share" "Share the session")
            (plugin K.l "zellij:layout-manager" "Layout manager")
          ];

    docs = [
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

  ghostty = {
    binds = [
      (keysLib.ghostty.bind {
        on = on.ctrlShift K.equal;
        action = "increase_font_size:1";
        desc = "Bigger font";
        group = "Font";
      })
      (keysLib.ghostty.bind {
        on = on.ctrlShift K.minus;
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
        on = on.ctrlShift K.c;
        action = "copy_to_clipboard";
        desc = "Copy";
        group = "Clipboard";
      })
      (keysLib.ghostty.bind {
        on = on.ctrlShift K.v;
        action = "paste_from_clipboard";
        desc = "Paste";
        group = "Clipboard";
      })
      (keysLib.ghostty.bind {
        on = on.ctrlShift K.r;
        action = "reload_config";
        desc = "Reload the terminal config";
        group = "Terminal";
      })
    ];
  };

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
        keys = "→ / End";
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
