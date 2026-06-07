{ lib, config, ... }:

lib.mkIf config.isWork {
  home-manager.users.amirsalar.custom = {
    # Work skills inherit claudeCode.defaultSkillMode ("user-invocable-only"):
    # `/divar-pages` etc. work but stay out of the model's context.
    claudeCode.enableWork = true;

    agentSkills = {
      sources.work-private = {
        input = "work-skills";
        subdir = ".";
        filter.maxDepth = 2;
      };
      skills = [
        "divar-pages"
        "divar-form-pages"
        "divarrpc-routing"
      ];
    };
  };
}
