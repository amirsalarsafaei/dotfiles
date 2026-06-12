{ lib, config, ... }:

lib.mkIf config.isWork {
  home-manager.users.amirsalar.custom = {
    # Work skills inherit claudeCode.defaultSkillMode ("user-invocable-only"):
    # `/divar-widgets` etc. work but stay out of the model's context.
    claudeCode.enableWork = true;

    agentSkills = {
      sources.work-private = {
        input = "work-skills";
        subdir = ".";
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
}
