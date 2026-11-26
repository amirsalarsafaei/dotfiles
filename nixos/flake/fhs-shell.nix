{ pkgs }:
let
  fhs = pkgs.buildFHSEnv {
    name = "fhs";
    targetPkgs =
      p:
      with p;
      [
        bashInteractive
        coreutils
        which
        python3
        uv
        git
        curl
        gcc
        gnumake
        pkg-config
        openssl
        zlib
      ];
    runScript = "bash";
  };
in
pkgs.mkShell {
  shellHook = ''
    if [ -z "''${FHS_SHELL_ACTIVE:-}" ]; then
      export FHS_SHELL_ACTIVE=1
      if [ -f "$0" ]; then
        exec ${fhs}/bin/fhs "$0"
      fi
      exec ${fhs}/bin/fhs
    fi
  '';
}
