{ pkgs, currentHostname, currentSystem, ... }: {
  home.packages =
    # Development Tools
    let devTools = [
      # Languages and Compilers
      pkgs.go
      pkgs.rustup
      pkgs.nodejs_22
      pkgs.kotlin
      pkgs.gcc
      pkgs.libgcc
      (pkgs.python3Full.withPackages (ppkgs: [
        ppkgs.libtmux
        ppkgs.pylint-venv
      ]))

      # Development Utilities
      pkgs.cmake
      pkgs.pkg-config
      pkgs.openssl_3_4
      pkgs.gnumake
      pkgs.just
      pkgs.devenv
      pkgs.nixd
      pkgs.gh
      pkgs.git-crypt
      pkgs.sops
      pkgs.unzip
      pkgs.postman
      pkgs.docker
      pkgs.docker-compose
      pkgs.gore
      pkgs.devbox
      pkgs.bazel
      pkgs.kubernetes-helm
      pkgs.amp-cli
    ];
    
    # Language Servers, Formatters, Linters, and Debuggers
    devTooling = [
      # Nix
      pkgs.nil                   # Nix LSP
      pkgs.nixpkgs-fmt           # Nix formatter
      pkgs.statix                # Nix linter
      
      # Go
      pkgs.gopls                 # Go LSP
      pkgs.golangci-lint         # Go linter
      pkgs.delve                 # Go debugger
      pkgs.goimports-reviser
      pkgs.golangci-lint-langserver
      pkgs.gotestsum
      
      # Rust
      # pkgs.rustfmt               # Rust formatter
      # pkgs.clippy                # Rust linter
      
      # C/C++
      pkgs.clang-tools           # C/C++ LSP (clangd) and formatter (clang-format)
      pkgs.cppcheck              # C/C++ linter
      pkgs.gdb                   # C/C++ debugger
      pkgs.lldb                  # Alternative C/C++ debugger
      
      # Kotlin
      pkgs.kotlin-language-server # Kotlin LSP
      pkgs.ktlint                # Kotlin linter and formatter

      # SQL
      pkgs.sqls
      
      # Python
      pkgs.pyright               # Python LSP
      pkgs.black                 # Python formatter
      pkgs.ruff                  # Fast Python linter
      pkgs.mypy                  # Python type checker
      
      # Protobuf
      pkgs.buf                   # Protobuf toolkit
      pkgs.protobuf              # Protocol Buffers compiler
      pkgs.protolint             # Protobuf linter
      
      # YAML/JSON
      pkgs.yaml-language-server  # YAML LSP
      pkgs.nodePackages.vscode-json-languageserver # JSON LSP
      pkgs.yamllint              # YAML linter
      pkgs.yamlfmt
      pkgs.yq-go                 # YAML processor
      pkgs.jq                    # JSON processor

      # JS/TS
      pkgs.typescript-language-server
      pkgs.vscode-langservers-extracted
      pkgs.nodePackages.eslint    # JavaScript/TypeScript linter
      
      # Lua
      pkgs.lua-language-server    # Lua LSP
      pkgs.luaformatter           # Lua formatter
      
      # Docker
      pkgs.dockerfile-language-server-nodejs  # Dockerfile LSP
      pkgs.docker-compose-language-service
      pkgs.hadolint               # Dockerfile linter
      
      # General
      pkgs.nodePackages.prettier # Formatter for many languages
      pkgs.efm-langserver       # General purpose LSP
      pkgs.shellcheck           # Shell script linter
      
    ];

    # Terminal and Shell
    terminalTools = [
      # Terminal Emulators
      pkgs.kitty
      pkgs.wezterm
      
      # Shell and Plugins
      pkgs.zsh
      pkgs.oh-my-zsh
      pkgs.zsh-fast-syntax-highlighting
      pkgs.zsh-powerlevel10k
      pkgs.zsh-autocomplete
      
      # Terminal Multiplexers
      pkgs.tmux
      pkgs.tmuxinator
      
      # Terminal Editors
      pkgs.neovim
    ];

    # CLI Tools
    cliTools = [
      # File and Text Processing
      pkgs.fd
      pkgs.ripgrep
      pkgs.jq
      pkgs.yq-go
      pkgs.fzf
      pkgs.coreutils-full
      pkgs.ncdu
      pkgs.zip
      pkgs.p7zip
      pkgs.gzip
      pkgs.bzip2
      pkgs.xz
      pkgs.tree
      pkgs.bat
      
      # System Information
      pkgs.neofetch
      pkgs.acpi
      
      # Fun CLI Tools
      pkgs.cowsay
      pkgs.sl
      pkgs.asciiquarium
      pkgs.xcowsay
    ];

    # Network Tools
    networkTools = [
      pkgs.mtr
      pkgs.iperf3
      pkgs.dnsutils
      pkgs.ldns
      pkgs.ipcalc
      pkgs.nmap
      pkgs.nload
      pkgs.sing-box
      pkgs.openfortivpn
      pkgs.openconnect
      pkgs.telepresence2
      pkgs.ngrok
      pkgs.iptables
    ];

    # Infrastructure and Cloud
    infraTools = [
      pkgs.kubectl
      pkgs.kubectl-neat
      pkgs.k9s
      pkgs.stern
      pkgs.awscli2
      pkgs.argo-rollouts
    ];

    # Desktop Applications
    desktopApps = [
      pkgs.obsidian
      pkgs.vlc
      pkgs.telegram-desktop
      pkgs.spotify-player
      pkgs.syncthing
      pkgs.texstudio
      (if currentHostname == "rog" then
        (pkgs.chromium.override {
          commandLineArgs = [
            "--ozone-platform=wayland"
            "--enable-wayland-ime"
            "--enable-features=WaylandWindowDecorations"
            "--disable-gpu-compositing"
          ];
        })
      else pkgs.chromium)
    ];

    # Wayland and Desktop Environment
    waylandTools = [
      pkgs.grim
      pkgs.slurp
      pkgs.hyprpaper
      pkgs.wl-clipboard
      pkgs.wofi
      pkgs.rofi-wayland
      pkgs.rofi-pass-wayland
      pkgs.wofi-pass
      pkgs.wtype
      pkgs.libnotify
      pkgs.pavucontrol
      pkgs.xorg.xwininfo
    ];

    # Security and Authentication
    securityTools = [
      pkgs.totp-cli
      (pkgs.pass.withExtensions
        (exts: [ exts.pass-otp ]))
    ];

    # Fonts
    fonts = [
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.hack
      pkgs.nerd-fonts.meslo-lg
      pkgs.nerd-fonts.ubuntu-mono
      pkgs.nerd-fonts.inconsolata
      pkgs.nerd-fonts.fantasque-sans-mono
      pkgs.nerd-fonts.victor-mono
      pkgs.nerd-fonts.iosevka-term-slab
      pkgs.nerd-fonts.iosevka
      pkgs.meslo-lgs-nf
    ];

    # Miscellaneous
    miscTools = [
      pkgs.jemalloc
      pkgs.ffmpeg_7-full
      pkgs.libimobiledevice
      pkgs.ifuse
      pkgs.xdg-utils
      pkgs.w3m
      pkgs.android-tools
      pkgs.obs-studio
    ];

    # Platform-specific packages
    platformSpecific = pkgs.lib.optionals (currentSystem == "x86_64-linux") [
      pkgs.zoom-us
      pkgs.android-studio
      pkgs.discord
      pkgs.insomnia
    ];

  in
    devTools ++
    devTooling ++
    terminalTools ++
    cliTools ++
    networkTools ++
    infraTools ++
    desktopApps ++
    waylandTools ++
    securityTools ++
    fonts ++
    miscTools ++
    platformSpecific;
}
