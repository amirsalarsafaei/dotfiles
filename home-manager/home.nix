{ pkgs, config, ... }:
let
  homeDir = config.home.homeDirectory;
  tmuxWindowName = pkgs.tmuxPlugins.mkTmuxPlugin {
    pname = "window-manager";
    pluginName = "window-manager";
    version = "2023-12-01";
    src = pkgs.fetchFromGitHub {
      owner = "ofirgall";
      repo = "tmux-window-name";
      rev = "dc97a79ac35a9db67af558bb66b3a7ad41c924e7";
      sha256 = "048j942jgplqvqx65ljfc278fn7qrhqx4bzmgzcvmg9kgjap7dm3";
    };
  };
in
{
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };
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
	pkgs.telepresence2
    (pkgs.jetbrains.goland.override {
      vmopts = ''
                			  -Xms128m
                				-Xmx1024m
                				-XX:ReservedCodeCacheSize=512m
                				-XX:+IgnoreUnrecognizedVMOptions
                				-XX:+UseG1GC
                				-XX:SoftRefLRUPolicyMSPerMB=50
                				-XX:CICompilerCount=2
                				-XX:+HeapDumpOnOutOfMemoryError
                				-XX:-OmitStackTraceInFastThrow
                				-ea
                				-Dsun.io.useCanonCaches=false
                				-Djdk.http.auth.tunneling.disabledSchemes=""
                				-Djdk.attach.allowAttachSelf=true
                				-Djdk.module.illegalAccess.silent=true
                				-Dkotlinx.coroutines.debug=off
                				-XX:ErrorFile=$USER_HOME/java_error_in_idea_%p.log
                				-XX:HeapDumpPath=$USER_HOME/java_error_in_idea.hprof

        						--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
        	    				--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED

                				-javaagent:/home/amirsalar/ja-netfilter/ja-netfilter.jar=jetbrains

        						-Dawt.toolkit.name=WLToolkit
                			'';
    })
    (pkgs.jetbrains.webstorm.override {
      vmopts = ''

			-Xms128m
			-Xmx1024m
			-XX:ReservedCodeCacheSize=512m
			-XX:+IgnoreUnrecognizedVMOptions
			-XX:+UseG1GC
			-XX:SoftRefLRUPolicyMSPerMB=50
			-XX:CICompilerCount=2
			-XX:+HeapDumpOnOutOfMemoryError
			-XX:-OmitStackTraceInFastThrow
			-ea
			-Dsun.io.useCanonCaches=false
			-Djdk.http.auth.tunneling.disabledSchemes=""
			-Djdk.attach.allowAttachSelf=true
			-Djdk.module.illegalAccess.silent=true
			-Dkotlinx.coroutines.debug=off
			-XX:ErrorFile=$USER_HOME/java_error_in_idea_%p.log
			-XX:HeapDumpPath=$USER_HOME/java_error_in_idea.hprof

			--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
			--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED

			-javaagent:/home/amirsalar/ja-netfilter/ja-netfilter.jar=jetbrains
			-Dawt.toolkit.name=WLToolkit
			'';
    })
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


    (pkgs.python3.withPackages (ppkgs: [
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
    TMUX_WINDOW_NAME_PATH = "${tmuxWindowName}/share/tmux-plugins/window-manager";
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
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellGlobalAliases = {
      "vim" = "nvim";
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

    initExtra = ''
      source ${homeDir}/.p10k.zsh

      ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE

      VI_MODE_SET_CURSOR=true

      function tmux-window-name() {
        (${tmuxWindowName}/share/tmux-plugins/window-manager/scripts/rename_session_windows.py &)
      }

      add-zsh-hook chpwd tmux-window-name

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

          set -g @catppuccin_status_modules_right "kube session"
          set -g @catppuccin_status_modules_left "uptime cpu battery"
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
      # {
      #   plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
      #     pname = "kube";
      #     pluginName = "kube";
      #     version = "2023-12-01";
      #     src = pkgs.fetchFromGitHub {
      #       owner = "amirsalarsafaei";
      #       repo = "tmux-kube";
      #       rev = "v1.0.0";
      #       sha256 = "1gx5f6qylzcqn6y3i1l92j277rqjrin7kn86njvn174d32wi78y8";
      #     };
      #   };
      # }
      tmuxWindowName
      pkgs.tmuxPlugins.vim-tmux-navigator
    ];
  };
}