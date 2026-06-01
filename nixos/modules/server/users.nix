{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.user;
in
{
  options.custom.user = {
    name = lib.mkOption {
      type = lib.types.str;
      example = "alice";
      description = "Primary interactive user account for this host.";
    };

    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys allowed for the primary user.";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.sshAuthorizedKeys != [ ];
        message = "custom.user.sshAuthorizedKeys must contain at least one SSH public key.";
      }
    ];

    users.users.${cfg.name} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = cfg.sshAuthorizedKeys;
      hashedPassword = "$6$NvI83LZtu9m3tUDy$j95BrryM6s0K6MsV/L4izJJj4yf/QwkMc0jltKIAVOfoMehsd0hJYSTddjwKsGrG.vW3vF6YtZFzDtcdjhZ3s0";
      packages = with pkgs; [
        htop
        ripgrep
        git
        fastfetch
        tmux
        neovim
      ];
      shell = pkgs.zsh;
    };

    users.users.root = {
      openssh.authorizedKeys.keys = cfg.sshAuthorizedKeys;
      hashedPassword = "$6$NvI83LZtu9m3tUDy$j95BrryM6s0K6MsV/L4izJJj4yf/QwkMc0jltKIAVOfoMehsd0hJYSTddjwKsGrG.vW3vF6YtZFzDtcdjhZ3s0";
      shell = pkgs.zsh;
    };

    users.users.khardal = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1r9m7OT6rVxzaPytgYLvJcGnXClAPjgkKYqXvhp0vQ"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICjztTFp0cZwLYpJvGymNDV/XcrViT73hr90tnkzWAVH"
      ];
    };
  };
}
