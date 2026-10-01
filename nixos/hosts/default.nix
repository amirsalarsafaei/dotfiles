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
    nixosProfiles = [
      "base"
      "server"
    ];
    homeProfiles = [
      "base"
      "dev"
    ];
    useSops = false;
    extraModules = [ disko.nixosModules.disko ];
  };
}
