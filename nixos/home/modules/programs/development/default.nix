{ dotfilesRoot, ... }:
{
  imports = [
    ./git.nix
    ./ssh.nix
    ./nixtools.nix
    ./vscode.nix
    ./texlive.nix
    ./distrobox.nix
    ./zoxide.nix
  ];

  programs.navi = {
    enable = true;
    enableZshIntegration = false;
    settings = {
      cheats = {
        path = "${dotfilesRoot}/navi-cheats";
      };
    };
  };
}
