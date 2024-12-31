{ pkgs, config, ... }:
let
  homeDir = config.home.homeDirectory;
in
{
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };
  nixpkgs.overlays = [
    (final: prev: {
      postman = prev.postman.overrideAttrs (old: rec {
        version = "20241026182607";
        src = final.fetchurl {
          url = "https://dl.pstmn.io/download/latest/linux_arm";
          sha256 = "14pp3frips0nwdb3xxryyixakl6bbxi94jkd1aq40xg6pcl2s58g";
          name = "${old.pname}-${version}.tar.gz";
        };
        buildInputs = old.buildInputs ++ [ pkgs.xdg-utils ];
        postFixup = ''
          pushd $out/share/postman
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" postman
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" chrome_crashpad_handler
          for file in $(find . -type f \( -name \*.node -o -name postman -o -name \*.so\* \) ); do
            ORIGIN=$(patchelf --print-rpath $file); \
            patchelf --set-rpath "${pkgs.lib.makeLibraryPath old.buildInputs}:$ORIGIN" $file
          done
          popd
          wrapProgram $out/bin/postman --set PATH ${pkgs.lib.makeBinPath [ pkgs.openssl pkgs.xdg-utils ]}:\$PATH
        '';

      });
    })
  ];
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "amirsalar";
  home.homeDirectory = "/home/amirsalar";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # enviroent.
  home.packages = [
    # Dev Tools
    pkgs.fd
    pkgs.ffmpeg_7-full
    pkgs.libimobiledevice
    pkgs.ifuse
    pkgs.xdg-utils
    pkgs.iptables
    (pkgs.pass.withExtensions
      (exts: [ exts.pass-otp ]))
    pkgs.rofi-pass-wayland
    pkgs.wtype
    pkgs.wofi-pass
    pkgs.xorg.xwininfo
    pkgs.w3m
    pkgs.pavucontrol
    pkgs.sing-box
    pkgs.handbrake
    pkgs.wofi
    pkgs.rofi-wayland
    pkgs.ngrok
    pkgs.postman
    pkgs.vlc
    pkgs.telegram-desktop
    pkgs.openfortivpn
    pkgs.pkg-config
    pkgs.openssl_3_3
    pkgs.telepresence2
    pkgs.asciiquarium
    pkgs.docker
    pkgs.docker-compose
    pkgs.kitty
    pkgs.libnotify
    pkgs.neofetch
    pkgs.wezterm
    pkgs.xcowsay
    pkgs.neovim
    pkgs.just
    pkgs.tmux
    pkgs.tmuxinator

    (pkgs.python3Full.withPackages (ppkgs: [
      ppkgs.libtmux
    ]))
    pkgs.zsh
    pkgs.oh-my-zsh
    pkgs.zsh-fast-syntax-highlighting
    pkgs.zsh-powerlevel10k
    pkgs.zsh-autocomplete
    pkgs.go
    pkgs.rustup
    pkgs.unzip
    pkgs.nodejs_22

    # Infrastructure packages
    pkgs.kubectl
    pkgs.k9s
    pkgs.stern
    pkgs.awscli2

    # Misc
    pkgs.grim
    pkgs.slurp
    pkgs.hyprpaper
    pkgs.android-tools
    pkgs.wl-clipboard
    pkgs.cowsay
    pkgs.libgcc
    pkgs.gcc
    pkgs.sl
    pkgs.coreutils-full
    pkgs.gnumake
    pkgs.acpi

    # Cli Tools
    pkgs.ripgrep
    pkgs.jq
    pkgs.yq-go
    pkgs.fzf

    # Network tools
    pkgs.mtr
    pkgs.iperf3
    pkgs.dnsutils
    pkgs.ldns
    pkgs.ipcalc
    pkgs.nmap
    pkgs.gh
    pkgs.nerdfonts


    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".gitconfig-work".text = ''
            [user]
      					name = "Amirsalar Safaei"
      					email = "amirsalar.safaei@divar.ir"
      							'';
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/amirsalar/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${homeDir}/go";
    GOPRIVATE = "git.divar.cloud,git.cafebazaar.ir";
    GOBIN = "${homeDir}/.local/bin";
    PATH = "$PATH:/usr/local/bin";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  xdg.configFile = {
    "tmuxinator" = {
      source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/personal/dotfiles/tmuxinator";
      recursive = true;
    };
    "nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/personal/dotfiles/nvim";
      recursive = true;
    };
  };


  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "Amirsalar Safaei";
    userEmail = "amirs.s.g.o@gmail.com";
    extraConfig = {
      url."ssh://git@git.divar.cloud/".insteadOf = "https://git.divar.cloud/";
    };
    includes = [
      {
        path = "${homeDir}/.gitconfig-work";
        condition = "gitdir:${homeDir}/divar/";
      }
    ];
  };
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "asdf"
        "history"
        "encode64"
        "docker"
        "docker-compose"
        "tmux"
        "virtualenv"
        "aws"
        "battery"
        "aliases"
        "command-not-found"
        "golang"
        "kubectl"
        "kubectx"
        "dotenv"
        "git-prompt"
        "tmuxinator"
        "vi-mode"
      ];
    };
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
    };
    syntaxHighlighting.enable = true;

    shellGlobalAliases = {
      "vim" = "nvim";
      pbcopy = "wl-copy";
      pbpaste = "wl-paste";
      gitrecent = "git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'";
      gitshort = "git rev-parse --short=8 HEAD";
    };
    shellAliases = {
      "vpn" = "pidof openfortivpn || sudo cat ~/totp-pass | totp-cli generate divar vpn | sudo openfortivpn";
    };

    plugins = [
      {
        name = "zsh-powerlevel10k";
        src = pkgs.zsh-powerlevel10k.src;
        file = "powerlevel10k.zsh-theme";
      }
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting.src;
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete.src;
      }
    ];

    initExtraFirst = ''
      # Autocomplete settings
      zstyle ':autocomplete:*' min-input 1
      zstyle ':autocomplete:*' min-delay 0.05  # seconds (float)
      zstyle ':autocomplete:*' max-lines 50%
      zstyle ':autocomplete:history-search:*' list-lines 16
      zstyle ':autocomplete:history-incremental-search-*:*' list-lines 16
      zstyle ':autocomplete:*' recent-dirs off
      zstyle ':autocomplete:*' insert-unambiguous yes
      zstyle ':autocomplete:*' widget-style menu-select
      zstyle ':autocomplete:*' fzf-completion yes
      zstyle ':autocomplete:*' async yes
      zstyle ':autocomplete:*' list-lines 10
      zstyle ':autocomplete:*' delay 0.1
    '';

    initExtra = ''
            source ${homeDir}/.p10k.zsh

            ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE

            VI_MODE_SET_CURSOR=true

            # Load personal shell files if present
            #___MY_VMOPTIONS_SHELL_FILE="{HOME}/.jetbrains.vmoptions.sh"
            #if [ -f "{___MY_VMOPTIONS_SHELL_FILE}" ]; then
            #  . "{___MY_VMOPTIONS_SHELL_FILE}"
            #fi

            # Key bindings
            bindkey -M viins '^I' menu-select
            bindkey -M viins "$terminfo[kcbt]" menu-select
            bindkey -M vicmd '^I' menu-select
            bindkey -M vicmd "$terminfo[kcbt]" menu-select
            bindkey -M menuselect '^I' menu-complete
            bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
            bindkey -M vicmd '^E' autosuggest-accept
      			if [ -z "$TMUX" ] && [ "$TERM" = "xterm-kitty" ]; then
      			  exec tmux new-session && exit;
      			fi
            source ~/zshsecret
    '';
  };
  programs.alacritty = {
    enable = true;
    settings = {
      shell = {
        program = "zsh";
        args = [ "-l" "-c" "tmuxinator mux" ];
      };
      env.TERM = "xterm-256color";
      window = {
        padding.x = 10;
        padding.y = 10;
        dynamic_padding = true;
        opacity = 0.9;
        decorations = "Buttonless";
        startup_mode = "Maximized";
      };
      font = {
        normal.family = "MesloLGS Nerd Font";
        size = 12;
      };
    };
  };
  programs.kitty = {
    enable = true;
    environment.TERM = "xterm-256color";
    extraConfig = ''
            background_opacity 0.8

            window_padding_width 7
            font_family MesloLGS Nerd Font
      														'';
  };
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    disableConfirmationPrompt = true;
    historyLimit = 100000;
    keyMode = "vi";
    tmuxinator.enable = true;
    mouse = true;

    extraConfig = ''
      setw -g xterm-keys on
      set -s escape-time 10                     # faster command sequences
      set -sg repeat-time 600                   # increase repeat timeout
      set -s focus-events on

      set -g prefix2 C-a                        # GNU-Screen compatible prefix
      bind C-a send-prefix -2

      # Navigation ------
      bind C-c new-session
      bind C-f command-prompt -p find-session 'switch-client -t %%'
      bind BTab switch-client -l  
      bind - split-window -c '#{pane_current_path}' -v
      bind _ split-window -c '#{pane_current_path}' -h
      bind = split-window -c '#{pane_current_path}' -v -l '20%'
      bind + split-window -c '#{pane_current_path}' -h -l '20%'
      # pane navigation
      bind -r h select-pane -L # move left 
      bind -r j select-pane -D # move down 
      bind -r k select-pane -U # move up 
      bind -r l select-pane -R # move right
      bind > swap-pane -D       # swap current pane with the next one
      bind < swap-pane -U       # swap current pane with the previous one


      # pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # window navigation
      unbind n
      unbind p
      bind -r C-h previous-window # select previous window
      bind -r C-l next-window     # select next window
      bind Tab last-window        # move to last active window

      set -g default-terminal "tmux-256color"

      set-option -g status-interval 5
      set-option -g automatic-rename on

      set-option -g automatic-rename-format "#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{b:pane_current_path}:#{pane_current_command}}"
    '';


    plugins = [
      {
        plugin = pkgs.tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour "macchiato" # latte,frappe, macchiato or mocha

          set -g @catppuccin_window_left_separator ""
          set -g @catppuccin_window_right_separator " "
          set -g @catppuccin_window_middle_separator " █"
          set -g @catppuccin_window_number_position "right"


          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text "#W"

          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text "#W"

          set -g @catppuccin_status_modules_right "session"
          set -g @catppuccin_status_modules_left "cpu battery"
          set -g @catppuccin_status_left_separator  " "
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"
          set -g @catppuccin_uptime_text "#(uptime | sed 's/^[^,]*up *//; s/, *[[:digit:]]* user.*//g; s/ day.*, */d /; s/:/h /; s/ min//; s/$/m/')"

          set -g @catppuccin_directory_text "#{pane_current_path}"
        '';
      }
      pkgs.tmuxPlugins.cpu
      pkgs.tmuxPlugins.yank
      {
        plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
          pname = "battery";
          pluginName = "battery";
          version = "2023-12-01";
          src = pkgs.fetchFromGitHub {
            owner = "tmux-plugins";
            repo = "tmux-battery";
            rev = "48fae59ba4503cf345d25e4e66d79685aa3ceb75";
            sha256 = "1gx5f6qylzcqn6y3i1l92j277rqjrin7kn86njvn174d32wi78y8";
          };
        };
      }
      pkgs.tmuxPlugins.vim-tmux-navigator
    ];
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "~/Pictures/lockscreen.png";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          placeholder_text = ''\'<span foreground="##cad3f5">Password...</span>'\'';
          shadow_passes = 2;
        }
      ];
    };
  };
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;

      preload =
        [ "~/Pictures/lockscreen.png" ];

      wallpaper = [
        ",~/Pictures/lockscreen.png"
      ];
    };

  };
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar =
        {
          layer = "top";
          exclusive = true;
          battery = {
            format = " \t{capacity}%";
            format-charging = "󰢝 \t{capacity}%";
            format-plugged = " \t{capacity}%";
            interval = 30;
          };
          clock = {
            format = "{:%H:%M:%S}";
            interval = 1;
          };
          cpu = {
            format = " \t{usage}%";
            interval = 5;
          };
          "custom/absclock" = {
            exec = "date +%s";
            format = "{}";
            interval = 1;
            return-type = "{}";
          };
          "custom/loadavg" = {
            exec = "cat /proc/loadavg | head -c 14";
            format = "Load average: {}";
            interval = 1;
            return-type = "{}";
          };
          "custom/uptime" = {
            exec = "uptime -p | sed 's/up //g' -";
            format = "Uptime: {}";
            interval = 60;
            return-type = "{}";
          };
          height = 33;
          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = "Don't idle";
              deactivated = "Idling";
            };
          };
          memory = {
            format = " \t{}%";
            interval = 5;
          };
          "hyprland/window" = {
            format = "{}";
            max-length = 30;
          };
          modules-center = [ ];
          modules-left = [ "hyprland/workspaces" "tray" "network" "hyprland/window" ];
          modules-right = [ "temperature" "cpu" "memory" "wireplumber" "battery" "hyprland/language" "clock" ];
          network = {
            format = "Net via {ifname}";
            format-disconnected = "No net";
            format-wifi = "{essid} ({signalStrength}%)  ";
            tooltip-format = "{ipaddr}/{cidr}";
          };
          position = "top";
          temperature = {
            format = "\t{temperatureC}°C";
            interval = 1;
          };
          tray = {
            spacing = 10;
          };
          wireplumber = {
            format = " \t{volume}%";
            format-muted = "\tmute";
            on-click = "pavucontrol";
            scroll-step = 1;
          };
        };

    };
  };
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
      };

      listener = [
        {
          timeout = 100;
          on-timeout = "hyprlock";
        }
        {
          timeout = 1200;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/x-extension-htm" = [ "chromium.desktop" ];
      "application/x-extension-html" = [ "chromium.desktop" ];
      "application/x-extension-shtml" = [ "chromium.desktop" ];
      "application/x-extension-xht" = [ "chromium.desktop" ];
      "application/x-extension-xhtml" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "video/quicktime" = [ "vlc-2.desktop" ];
      "video/x-matroska" = [ "vlc-4.desktop" "vlc-3.desktop" ];
      "x-scheme-handler/chrome" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };

    defaultApplications = {
      "application/x-extension-htm" = "chromium.desktop";
      "application/x-extension-html" = "chromium.desktop";
      "application/x-extension-shtml" = "chromium.desktop";
      "application/x-extension-xht" = "chromium.desktop";
      "application/x-extension-xhtml" = "chromium.desktop";
      "application/xhtml+xml" = "chromium.desktop";
      "text/html" = "chromium.desktop";
      "video/quicktime" = "vlc-2.desktop";
      "video/x-matroska" = "vlc-4.desktop";
      "x-scheme-handler/chrome" = "chromium.desktop";
      "x-scheme-handler/http" = "chromium.desktop";
      "x-scheme-handler/https" = "chromium.desktop";
      "x-scheme-handler/postman" = "chromium.desktop";
    };
  };
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        padding = 5;
        corner_radius = 10;
        frame_color = "#eceff1";
        font = "JetBrainsMono Nerd Font Mono";
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 1;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;
        progress_bar_corner_radius = 5;
        highlight = "#34a1db";
      };

      urgency_normal = {
        background = "#5f7296";
        foreground = "#eceff1";
        timeout = 10;
      };
    };
  };
}
