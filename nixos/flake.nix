{
  description = "NixOS configuration";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      systems = {
        x86_64 = "x86_64-linux";
        aarch64 = "aarch64-linux";
      };

      secrets = builtins.fromJSON (builtins.readFile ./secrets/secrets.json);

      # Helper function to create system configurations
      mkSystem =
        { system
        , hostname
        , username ? "amirsalar"
        , extraModules ? [ ]
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit secrets;
          };
          modules = [
            ./hosts/common/default.nix

            # Host-specific configuration
            ./hosts/${hostname}/configuration.nix

            # Hardware-specific configuration
            ./hosts/${hostname}/hardware-configuration.nix


            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    inherit system;
                    config.allowUnfree = true;
                  };

                  postman = prev.postman.overrideAttrs (old: rec {
                    version = "2025-01-15";
                    src = final.fetchurl (
                      if final.stdenv.hostPlatform.isAarch64 then {
                        url = "https://dl.pstmn.io/download/latest/linux_arm";
                        sha256 = "Lmb6M2eC2R8xG5802JLA5mLL+27rAlpdmV7xabqGuaI=";
                        name = "${old.pname}-${version}.tar.gz";
                      } else {
                        url = "https://dl.pstmn.io/download/latest/linux_64";
                        sha256 = "y260wmU+C0Y6wpeHuHe0mXuAZZgZ38qr2pGprhZJ7sE=";
                        name = "${old.pname}-${version}.tar.gz";
                      }
                    );
                    buildInputs = old.buildInputs ++ [ final.xdg-utils ];
                    postFixup = ''
                      pushd $out/share/postman
                      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" postman
                      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" chrome_crashpad_handler
                      for file in $(find . -type f \( -name \*.node -o -name postman -o -name \*.so\* \) ); do
                        ORIGIN=$(patchelf --print-rpath $file); \
                        patchelf --set-rpath "${final.lib.makeLibraryPath old.buildInputs}:$ORIGIN" $file
                      done
                      popd
                      wrapProgram $out/bin/postman --set PATH ${final.lib.makeBinPath [ final.openssl final.xdg-utils ]}:\$PATH
                    '';
                  });
                })

              ];
            }
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {
                  inherit secrets;
                  currentHostname = hostname;
                  currentSystem = system;
                  homeDir = "/home/${username}";
                  monitors = {
                    mainMonitor = "eDP-1";
                    secondaryMonitor = "HDMI-A-1";
                  };
                };
                users.${username} =
                  import ./home/default.nix;
              };
            }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        # MacBook (ARM)
        mac = mkSystem {
          system = systems.aarch64;
          hostname = "mac";
        };

        rog = mkSystem {
          system = systems.x86_64;
          hostname = "rog";
        };
      };
    };
}
