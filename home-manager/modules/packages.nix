{ pkgs, ... }: {
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
    pkgs.nload
  ];
}
