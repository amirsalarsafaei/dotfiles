# Import all overlays
{ nixpkgs-stable, system }:
[
  (import ./stable-packages.nix {
    inherit nixpkgs-stable system;
  })
]
