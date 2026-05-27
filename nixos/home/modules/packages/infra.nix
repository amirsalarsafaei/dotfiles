{ pkgs, inputs, ... }:
[
  pkgs.kubectl
  pkgs.kubectl-neat
  pkgs.kubelogin-oidc
  pkgs.k9s
  pkgs.kapp
  pkgs.kubeseal
  inputs.argonaut.packages.${pkgs.stdenv.hostPlatform.system}.default
  pkgs.stern
  pkgs.awscli2
  pkgs.argo-rollouts
  pkgs.argocd
  pkgs.argocd-vault-plugin
  pkgs.kubernetes-helm
  pkgs.kubernetes-helmPlugins.helm-s3
]
