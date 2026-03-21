final: prev:
let
  version = "0.104.1"; # Updated version

  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

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
      # Replace with real hash after first build attempt
      "x86_64-linux" = "US/Snsh4YXSUyp3yg1Xi1UoZPDyhqP5RHsolqQA/FQI=";
      "aarch64-linux" = prev.lib.fakeHash;
    }
    .${system};

  system = prev.stdenv.hostPlatform.system;
  target = targetFor system;
in
{
  gapcode = prev.stdenv.mkDerivation {
    pname = "gapcode";
    inherit version;

    src = prev.fetchurl {
      url = "https://gapgpt.app/releases/v${version}/gapcode-${target}.tar.gz";
      sha256 = sha256For system;
    };

    nativeBuildInputs = [ prev.autoPatchelfHook ];

    buildInputs = [
      prev.libcap
      prev.openssl
      prev.zlib
      prev.gcc-unwrapped.lib
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
}
