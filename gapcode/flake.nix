{
  description = "GapCode CLI - packaged from upstream binary";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system: nixpkgs.legacyPackages.${system};

      version = "0.104.0";

      targetFor =
        system:
        {
          "x86_64-linux" = "x86_64-unknown-linux-gnu";
          "aarch64-linux" = "aarch64-unknown-linux-gnu";
        }
        .${system};

      sha256For =
        system:
        {
          "x86_64-linux" = "sha256-npInju7+7vHMIdiKvF2jaSb/f6DoiCFUjCZbnPSL5F8=";
          "aarch64-linux" = nixpkgs.lib.fakeSha256;
        }
        .${system};

      mkGapcode =
        system:
        let
          pkgs = pkgsFor system;
          target = targetFor system;
        in
        pkgs.stdenv.mkDerivation {
          pname = "gapcode";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://gapgpt.app/releases/v${version}/gapcode-${target}.tar.gz";
            sha256 = sha256For system;
          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          buildInputs = [
            pkgs.libcap
            pkgs.openssl # provides libssl.so.3 + libcrypto.so.3
            pkgs.zlib
            pkgs.gcc-unwrapped.lib # libgcc_s.so.1
          ];

          installPhase = ''
            runHook preInstall

            bin=$(find . -maxdepth 3 \
              \( -name "gapcode" -o -name "gapcode-${target}" -o -name "codex" -o -name "codex-${target}" \) \
              -type f ! -name '*.tar.gz' | head -1)

            [ -n "$bin" ] || { echo "binary not found in archive"; exit 1; }

            install -Dm755 "$bin" "$out/bin/gapcode"

            runHook postInstall
          '';

          meta = {
            description = "GapCode CLI";
            homepage = "https://gapgpt.app";
            platforms = supportedSystems;
            mainProgram = "gapcode";
          };
        };

    in
    {
      packages = forAllSystems (system: {
        default = mkGapcode system;
        gapcode = mkGapcode system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/gapcode";
        };
      });

      overlays.default = final: prev: {
        gapcode = mkGapcode prev.stdenv.hostPlatform.system;
      };
    };
}
