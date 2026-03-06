{ config, ... }:
{
  programs.ssh = {
    enable = true;
    
    # Don't use old defaults - we'll define our own
    enableDefaultConfig = false;
    
    # Include sops-managed secrets
    includes = [ "~/.ssh/config.d/sops" ];
    
    # Global match block for all hosts
    matchBlocks."*" = {
      # Connection pooling for better performance
      controlMaster = "auto";
      controlPath = "~/.ssh/sockets/%r@%h-%p";
      controlPersist = "10m";
      
      # Keep connections alive
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
      
      # Add keys to agent automatically
      addKeysToAgent = "yes";
      
      # Security defaults
      hashKnownHosts = true;
      userKnownHostsFile = "~/.ssh/known_hosts";
      
      # Use identity file explicitly configured
      identitiesOnly = true;
    };
  };

  # Ensure SSH directories exist
  home.file.".ssh/config.d/.gitkeep".text = "";
  home.file.".ssh/sockets/.gitkeep".text = "";
}

