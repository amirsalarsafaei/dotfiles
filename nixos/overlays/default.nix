# Import all overlays
{ nixpkgs-stable, system }:
[
  (import ./stable-packages.nix nixpkgs-stable system)
]
