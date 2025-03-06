{ pkgs, currentHostname, currentSystem, ... }: {
  home.packages = [
    pkgs.ncdu
    pkgs.argo-rollouts
    pkgs.kotlin
    pkgs.git-crypt
    pkgs.sops
    pkgs.devenv
    pkgs.nixd
    pkgs.texstudio
    # Dev Tools
    pkgs.fd
    pkgs.totp-cli
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
    pkgs.wofi
    pkgs.rofi-wayland
    pkgs.ngrok
    # pkgs.postman
    pkgs.vlc
    pkgs.telegram-desktop
    pkgs.openfortivpn
    pkgs.pkg-config
    pkgs.openssl_3_4
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
      ppkgs.pylint-venv
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
    pkgs.nload
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
    (if currentHostname == "rog" then
      (pkgs.unstable.chromium.override {
        commandLineArgs = [
          "--ozone-platform=wayland"
          "--enable-wayland-ime"
          "--enable-features=WaylandWindowDecorations"
          "--disable-gpu-compositing"
        ];
      })
    else pkgs.chromium)
  ]
  ++ pkgs.lib.optionals (currentSystem == "x86_64-linux") [
    pkgs.zoom-us
    pkgs.android-studio
    pkgs.unstable.discord
  ];
}
