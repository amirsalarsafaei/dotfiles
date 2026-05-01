{ pkgs, argonaut, ... }:
[
  pkgs.kubectl
  pkgs.kubectl-neat
  pkgs.kubelogin-oidc
  pkgs.k9s
  argonaut
  pkgs.stern
  pkgs.awscli2
  pkgs.argo-rollouts
  pkgs.argocd
  pkgs.argocd-vault-plugin
  pkgs.kubernetes-helm
  pkgs.kubernetes-helmPlugins.helm-s3
]
