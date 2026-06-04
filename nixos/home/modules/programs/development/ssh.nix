{ ... }:
{
  programs.ssh = {
    enable = true;

    # Don't use old defaults - we'll define our own
    enableDefaultConfig = false;

    # Include sops-managed secrets
    includes = [ "~/.ssh/config.d/sops" ];

    # Global match block for all hosts
    settings."*" = {
      # Connection pooling for better performance
      ControlMaster = "auto";
      ControlPath = "~/.ssh/sockets/%r@%h-%p";
      ControlPersist = "10m";

      # Keep connections alive
      ServerAliveInterval = 60;
      ServerAliveCountMax = 3;

      # Add keys to agent automatically
      AddKeysToAgent = "yes";

      # Security defaults
      HashKnownHosts = "yes";
      UserKnownHostsFile = "~/.ssh/known_hosts";

      # Use identity file explicitly configured
      IdentitiesOnly = "yes";
    };

    # Bypass the gcr ssh-agent so the YubiKey (-sk) touch is handled by the client
    settings."git.divar.cloud".IdentityAgent = "none";
  };

  # Ensure SSH directories exist
  home.file.".ssh/config.d/.gitkeep".text = "";
  home.file.".ssh/sockets/.gitkeep".text = "";
}
