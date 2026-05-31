# Agent skills managed by agent-skills-nix.
# Add skill sources as flake inputs (flake = false), then reference them here.
#
# Example – to add a community skill repo:
#
#   1. In flake.nix inputs:
#      my-skills = { url = "github:owner/repo"; flake = false; };
#
#   2. Here, under sources:
#      my-skills = { input = "my-skills"; subdir = "skills"; };
#
#   3. Enable individual skills or all:
#      skills.enable = [ "some-skill" ];   # or skills.enableAll = true;
#
{ ... }:
{
  programs.agent-skills = {
    enable = true;

    # Skill sources – add entries here as you pin new repos in flake.nix
    sources = {
      commas-claude = {
        input = "commas-claude";
        subdir = "skills";
      };
    };

    # Sync targets – enable the agents you use. Skill selection
    # (`skills.enable` / `skills.enableAll`) is driven by the
    # `custom.agentSkills` wrapper in dev profile to avoid conflicting
    # definitions of `skills.enableAll` (bool vs list-of-string).
    targets = {
      agents.enable = true; # ~/.agents/skills (Amp)
      claude.enable = true;
    };
  };
}
