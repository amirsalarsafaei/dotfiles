{ nixpkgs-stable, nixpkgsConfig }:
[
  (import ./stable-packages.nix { inherit nixpkgs-stable nixpkgsConfig; })
]
