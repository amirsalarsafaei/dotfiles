{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.custom.user;
  plainUserPackageList = with pkgs; [
    bashInteractive
    bat
    btop
    curl
    dig
    eza
    fastfetch
    fd
    file
    fzf
    git
    htop
    jq
    less
    lsof
    nano
    nettools
    procps
    ripgrep
    tmux
    tree
    unzip
    vim
    wget
    yq-go
    zip
  ];
  mkPlainUser =
    _name: user:
    {
      isNormalUser = true;
      openssh.authorizedKeys.keys = user.sshAuthorizedKeys;
      packages = plainUserPackageList ++ user.packages;
      shell = pkgs.bashInteractive;
    }
    // lib.optionalAttrs (user.description != null) {
      inherit (user) description;
    }
    // lib.optionalAttrs (user.extraGroups != [ ]) {
      inherit (user) extraGroups;
    };
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

    extraUsers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              description = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "GECOS description for the extra user.";
              };

              sshAuthorizedKeys = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "SSH public keys allowed for this extra user.";
              };

              extraGroups = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Supplementary groups for this extra user.";
              };

              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Additional packages for this extra user.";
              };
            };

            config.description = lib.mkDefault name;
          }
        )
      );
      default = { };
      description = "Plain Linux-style extra users for server hosts.";
    };
  };

  config = {
    assertions =
      [
        {
          assertion = cfg.sshAuthorizedKeys != [ ];
          message = "custom.user.sshAuthorizedKeys must contain at least one SSH public key.";
        }
      ]
      ++ lib.mapAttrsToList
        (name: user: {
          assertion = user.sshAuthorizedKeys != [ ];
          message = "custom.user.extraUsers.${name}.sshAuthorizedKeys must contain at least one SSH public key.";
        })
        cfg.extraUsers;

    environment.systemPackages = plainUserPackageList;

    documentation.man.enable = true;
    programs.command-not-found.enable = true;
    programs.nix-ld.enable = true;

    users.users = lib.mapAttrs mkPlainUser cfg.extraUsers // {
      ${cfg.name} = {
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

      root = {
        openssh.authorizedKeys.keys = cfg.sshAuthorizedKeys;
        hashedPassword = "$6$NvI83LZtu9m3tUDy$j95BrryM6s0K6MsV/L4izJJj4yf/QwkMc0jltKIAVOfoMehsd0hJYSTddjwKsGrG.vW3vF6YtZFzDtcdjhZ3s0";
        shell = pkgs.zsh;
      };

      khardal = {
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1r9m7OT6rVxzaPytgYLvJcGnXClAPjgkKYqXvhp0vQ"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICjztTFp0cZwLYpJvGymNDV/XcrViT73hr90tnkzWAVH"
        ];
      };
    };
  };
}
