{ config, ... }:
{
  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;

    includes = [ "~/.ssh/config.d/sops" ];

    matchBlocks."*" = {
      controlMaster = "auto";
      controlPath = "~/.ssh/sockets/%r@%h-%p";
      controlPersist = "10m";

      serverAliveInterval = 60;
      serverAliveCountMax = 3;

      addKeysToAgent = "yes";

      hashKnownHosts = true;
      userKnownHostsFile = "~/.ssh/known_hosts";

      identitiesOnly = true;
    };
  };

  home.file.".ssh/config.d/.gitkeep".text = "";
  home.file.".ssh/sockets/.gitkeep".text = "";
}
