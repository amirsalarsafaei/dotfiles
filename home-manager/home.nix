{ pkgs, config, homeDir, ... }:
{
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };
  nixpkgs.overlays = [
    (final: prev: {
      postman = prev.postman.overrideAttrs (old: rec {
        version = "20241026182607";
        src = final.fetchurl (
          if pkgs.stdenv.hostPlatform.isAarch64 then {
            url = "https://dl.pstmn.io/download/latest/linux_arm";
            sha256 = "14pp3frips0nwdb3xxryyixakl6bbxi94jkd1aq40xg6pcl2s58g";
            name = "${old.pname}-${version}.tar.gz";
          } else {
            url = "https://dl.pstmn.io/download/latest/linux_64";
            sha256 = "10zcbjxm7810jpbgggsmdn3acprqhk3p3ci95hhjp4ss4fnwc663";
            name = "${old.pname}-${version}.tar.gz";
          }
        );
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

  home.username = "amirsalar";
  home.homeDirectory = "/home/amirsalar";

  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # enviroent.

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".gitconfig-work".text = ''
            [user]
      					name = "Amirsalar Safaei"
      					email = "amirsalar.safaei@divar.ir"
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${homeDir}/go";
    GOPRIVATE = "git.divar.cloud";
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

  programs.home-manager.enable = true;

  imports = [ ./modules ];
}
