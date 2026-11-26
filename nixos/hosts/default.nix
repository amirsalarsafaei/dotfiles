{ systems, disko }:
{
  g14 = {
    system = systems.x86_64;
    type = "nixos";
    users = [
      "amirsalar"
      "fateme"
    ];
    nixosProfiles = [
      "base"
      "desktop"
    ];
    homeProfiles = [ "full" ];
    userProfiles.fateme = [
      "base"
      "dev"
    ];
    sopsHomeUsers = [ "amirsalar" ];
  };

  t14 = {
    system = systems.x86_64;
    type = "nixos";
    users = [ "amirsalar" ];
    nixosProfiles = [
      "base"
      "desktop"
    ];
    homeProfiles = [ "full" ];
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
      "franksalar"
    ];
    useSops = true;
    useSopsHome = false;
    extraModules = [ disko.nixosModules.disko ];
  };
}
