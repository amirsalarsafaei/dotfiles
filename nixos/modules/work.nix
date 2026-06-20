{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  # The devar SDUI helper CLI, built from the same path input that feeds the
  # skill pack (inputs.devar = the local plugin repo root, ~/divar/devar). Lives
  # in this work-only module — next to the divar skills it backs — so it lands on
  # the work laptop alone and `devar <subcommand>` is on PATH instead of relying
  # on the repo's bin/devar build-on-first-call shim. `nix flake update devar`
  # re-copies the working tree, bumping both the skills and this binary.
  devarCli = pkgs.buildGoModule {
    pname = "devar";
    version = inputs.devar.shortRev or "unstable";
    src = inputs.devar;
    vendorHash = "sha256-azp+gNENR6TiND7/1N+OIZL0CPud9f+FwgI7Iic9Tnc=";
    subPackages = [ "." ];
    doCheck = false;
  };
in
lib.mkIf config.isWork {
  home-manager.users.amirsalar = {
    home.packages = [ devarCli ];

    custom = {
      # Work skills inherit claudeCode.defaultSkillMode ("user-invocable-only"):
      # `/divar-widgets` etc. work but stay out of the model's context.
      claudeCode.enableWork = true;
      # The directory-sourced devar marketplace + plugin only here — this is the
      # host with the ~/divar/devar checkout. See claudeCode.enableDevar.
      claudeCode.enableDevar = true;

      agentSkills = {
        sources.devar = {
          input = "devar";
          # The input is now the repo root (was the skills/ dir), so point skill
          # discovery at skills/.
          subdir = "skills";
          filter.maxDepth = 2;
        };
        skills = [
          "divar-widgets"
          "divar-form-pages"
          "divar-gateway"
          "divarrpc"
          "divar"
        ];
      };
    };
  };
}
