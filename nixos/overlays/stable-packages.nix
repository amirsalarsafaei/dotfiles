{ nixpkgs-stable, nixpkgsConfig }:
final: _: {
  stable = import nixpkgs-stable {
    inherit (final.stdenv.hostPlatform) system;
    config = nixpkgsConfig;
  };
}
