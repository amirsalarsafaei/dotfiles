{ ... }:
{
  services.openssh = {
    enable = true;
    ports = [
      22
      2200
      56777
    ];
    settings = {
      PubkeyAuthentication = true;

      PasswordAuthentication = false;

      KbdInteractiveAuthentication = false;

      PermitRootLogin = "prohibit-password";

      MaxSessions = 1000;

      MaxStartups = "100:30:500";
    };
    extraConfig = ''
      AddressFamily any
      AllowTcpForwarding yes
    '';
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      2200
      56777
    ];
  };

  services.fail2ban = {
    enable = false;
    bantime-increment.enable = true;
    jails = {
      sshd = {
        settings = {
          mode = "aggressive";
          maxretry = 3;
          findtime = 600;
          bantime = 3600;
        };
      };
    };

  };
}
