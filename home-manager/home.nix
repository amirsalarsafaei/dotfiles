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

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".gitconfig-work".text = ''
            [user]
      					name = "Amirsalar Safaei"
      					email = "amirsalar.safaei@divar.ir"
    '';
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
  imports = [ ./modules ];
}
