{
  nixpkgs,
  system,
  commonNixpkgsConfig,
}:
let
  pkgs = import nixpkgs ({ inherit system; } // commonNixpkgsConfig system);
  cudaPackages = pkgs.cudaPackages_12_9;
in
(pkgs.mkShell.override { stdenv = cudaPackages.backendStdenv; }) {
  packages = [
    cudaPackages.cudatoolkit
    cudaPackages.cuda_nvprof
    pkgs.zsh
  ];

  CUDA_HOME = cudaPackages.cudatoolkit;
  CUDA_PATH = cudaPackages.cudatoolkit;
  LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath [ cudaPackages.cudatoolkit ]}";

  shellHook = ''
    if [[ $- == *i* && -z "''${ZSH_VERSION:-}" ]]; then
      exec ${pkgs.zsh}/bin/zsh
    fi
  '';
}
