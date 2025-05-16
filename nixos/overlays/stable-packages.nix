# Access to stable packages
nixpkgs-stable: system: 
final: prev: {
  stable = import nixpkgs-stable {
    system = system;
    config = {
      android_sdk.accept_license = true;
      allowUnfree = true;
    };
  };
}
