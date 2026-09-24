{
  description = "Unified Nix configurations for all my machines";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
      # Enable after creating the cache and replacing the matching public key below.
      # "https://amirsalarsafaei-com.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      # Replace TODO with the exact public key from `cachix use amirsalarsafaei-com`.
      # "amirsalarsafaei-com.cachix.org-1:TODO"
    ];
    extra-experimental-features = "nix-command flakes";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprlock = {
      url = "github:hyprwm/hyprlock/v0.9.6";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    argonaut = {
      url = "github:darksworm/argonaut?ref=v2.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code.url = "github:sadjow/claude-code-nix";

    crit = {
      url = "github:tomasz-tomczyk/crit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Skill packs (raw SKILL.md repos — `flake = false`).
    # Wire them up under `custom.agentSkills.sources` and opt-in per skill
    # ID via `custom.agentSkills.skills`.
    samber-go-skills = {
      url = "github:samber/cc-skills-golang";
      flake = false;
    };

    # Zsh plugins (formerly in dev-home)
    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };
    fast-syntax-highlighting = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
    };
    zsh-nix-shell = {
      url = "github:chisui/zsh-nix-shell";
      flake = false;
    };

    commas-claude = {
      url = "git+https://github.com/3commas-io/commas-claude.git?ref=refs/tags/v1.0.4";
      flake = false;
    };

    # Personal website (Next.js frontend + Rust backend). Exposes the
    # NixOS module and package set consumed by franksalar.
    #
    # NOTE: this requires the nix-packaging fixes (src filters, sqlx offline
    # build, regenerated yarn.lock, Next.js standalone output) to be on the
    # referenced commit. Commit & push those to master, then re-lock with
    # `nix flake update amirsalarsafaei-com`. To build before pushing, deploy
    # with `--override-input amirsalarsafaei-com git+file:///home/amirsalar/personal/amirsalarsafaei.com`.
    amirsalarsafaei-com = {
      url = "github:amirsalarsafaei/amirsalarsafaei.com";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private skill pack + the devar CLI source — not in any public repo.
    # Sourced from the local working copy (the `devar@divar` Claude Code plugin
    # repo, cloned at ~/divar/devar) via a `path:` input rather than the git
    # remote, so local edits flow through without a commit/push/re-lock cycle and
    # no SSH round-trip to git.divar.cloud is needed to evaluate. Only the work
    # host (isWork, see modules/work.nix) ever forces this input — both the
    # agent-skills source (subdir `skills`) and the `devar` binary package build
    # from it — so other hosts never reference the path. The checkout must exist
    # on disk; `nix flake update devar` re-copies the current tree.
    devar = {
      url = "path:/home/amirsalar/divar/devar";
      flake = false;
    };

    # Avosh diet bot: Django app (admin + Mini App) and a Telegram bot (long
    # polling), exposed as `nixosModules.default`. No public remote yet, so
    # this is a local `path:` input — same rationale as `devar` above: local
    # edits flow straight through, no commit/push/re-lock cycle. Run
    # `nix flake update avosh-bot` to pick up on-disk changes for a build.
    avosh-bot = {
      url = "path:/etc/avosh-bot";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # system-bridge = {
    #   url = "path:/home/amirsalar/personal/system-bridge";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = inputs: import ./flake inputs;
}
