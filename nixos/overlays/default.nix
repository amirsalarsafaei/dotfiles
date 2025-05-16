# Import all overlays
{ nixpkgs-stable, system }:
[
  # Stable packages overlay
  (import ./stable-packages.nix nixpkgs-stable system)
  
  # Postman overlay
  (import ./postman.nix)
]
