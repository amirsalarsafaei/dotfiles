{ systems, disko }:
{
  g14 = {
    system = systems.x86_64;
    type = "nixos";
    users = [
      "amirsalar"
    ];
    extraModules = [ ];
  };

  t14 = {
    system = systems.x86_64;
    type = "nixos";
    users = [ "amirsalar" ];
    extraModules = [ disko.nixosModules.disko ];
  };

  orangepi = {
    system = systems.aarch64;
    type = "home-manager";
    users = [ "amirsalar" ];
    homeProfiles = [
      "base"
      "dev"
      "theme"
    ];
  };

  franksalar = {
    system = systems.x86_64;
    type = "nixos";
    users = [ "amirsalar" ];
    # Headless: skip the desktop common; pull only base + server.
    nixosProfiles = [
      "base"
      "server"
    ];
    # Reuse the same CLI dev tools as other machines.
    homeProfiles = [
      "base"
      "dev"
    ];
    # No sops setup on this host (uses the private flake instead).
    useSops = false;
    extraModules = [ disko.nixosModules.disko ];
  };
}
