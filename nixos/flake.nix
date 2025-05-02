{
  description = "NixOS configuration";

  nixConfig = {
    subtituters = [
      # nix community's cache server
      "https://nix-community.cachix.org"

      "https://hyprland.cachix.org"
      "https://cache.nixos.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      # nix community's cache server public key
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    hyprland.url = "github:hyprwm/Hyprland";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon-support.url = "github:tpwrules/nixos-apple-silicon/19b1103d09b4be12bdbf4c713b0e45fc434b5f6a";
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, apple-silicon-support, ... } @ inputs:
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
            inherit inputs;
            inherit apple-silicon-support;
          };
          modules = [
            ./hosts/common/default.nix

            # Host-specific configuration
            ./hosts/${hostname}/configuration.nix

            # Hardware-specific configuration
            ./hosts/${hostname}/hardware-configuration.nix


            {
              # System-wide nixpkgs configuration
              nixpkgs = {
                config = {
                  android_sdk.accept_license = true;
                  allowUnfree = true;
                };
                overlays = [
                  (final: prev: {
                    stable = import nixpkgs-stable {
                      inherit system;
                      config = {
                        android_sdk.accept_license = true;
                        allowUnfree = true;
                      };
                    };

                    postman = prev.postman.overrideAttrs (old: rec {
                      version = "2025-01-15";
                      src = final.fetchurl (
                        if final.stdenv.hostPlatform.isAarch64 then {
                          url = "https://dl.pstmn.io/download/latest/linux_arm";
                          sha256 = "rqv/a3tO+6p1vnFtiNkkI/gYYkHZn6C0pvztHVGhhkE=";
                          name = "${old.pname}-${version}.tar.gz";
                        } else {
                          url = "https://dl.pstmn.io/download/latest/linux_64";
                          sha256 = "saczZ6e3WxGstqD9kbfxVoQKnC0gHVqEZWiNL2GRLtM=";
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
              };
            }

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {
                  inherit secrets;
                  inherit inputs;
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
