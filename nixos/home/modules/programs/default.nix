{
  imports = [
    ./git.nix
    ./alacritty.nix
    ./kitty.nix
    ./ssh.nix
    ./tmux.nix
    ./hyprlock.nix
    ./waybar.nix
    ./rofi.nix
    ./ghostty.nix
    ./hyprland.nix
    ./vscode.nix
    ./texlive.nix
    ./distrobox.nix
    ./zoxide.nix
  ];

  programs.nix-search-tv.enableTelevisionIntegration = true;
}
