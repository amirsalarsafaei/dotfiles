{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.localKubernetes;
in
{
  options.custom.localKubernetes = {
    enable = lib.mkEnableOption "on-demand local Kubernetes with Minikube";

    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Default CPU limit per Minikube node; overridable with --cpus.";
    };

    memory = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8192;
      description = "Default memory limit in MiB per Minikube node; overridable with --memory.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = "Local Kubernetes requires virtualisation.docker.enable.";
      }
    ];

    environment.systemPackages = [
      (lib.lowPrio pkgs.minikube)
      pkgs.kubectl
    ];

    environment.sessionVariables = {
      MINIKUBE_DRIVER = "docker";
      MINIKUBE_CONTAINER_RUNTIME = "containerd";
      MINIKUBE_CPUS = toString cfg.cpus;
      MINIKUBE_MEMORY = toString cfg.memory;
    };
  };
}
