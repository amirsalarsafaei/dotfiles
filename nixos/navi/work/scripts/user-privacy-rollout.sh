set -euo pipefail

die() {
  printf 'user-privacy-rollout: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: bash user-privacy-rollout.sh sets' \
    '       bash user-privacy-rollout.sh rollouts APPLICATION_SET' \
    '       bash user-privacy-rollout.sh preview APPLICATION_SET ROLLOUT' \
    '       bash user-privacy-rollout.sh promote APPLICATION_SET ROLLOUT'
}

mode="${1:-}"
case "$mode" in
  sets) [[ $# -eq 1 ]] || die 'sets takes no arguments' ;;
  rollouts) [[ $# -eq 2 ]] || die 'rollouts needs an ApplicationSet' ;;
  preview|promote) [[ $# -eq 3 ]] || die "$mode needs an ApplicationSet and Rollout" ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac

argo=(argocd --server argocd.divar.cloud --grpc-web)
apps=$("${argo[@]}" app list --project user-privacy -o json)

if [[ "$mode" == sets ]]; then
  jq -r '[.[] | .metadata.ownerReferences[]? | select(.kind == "ApplicationSet") | .name] | unique[]' <<< "$apps"
  exit 0
fi

app_set="$2"
selected=$(jq -c --arg app_set "$app_set" '
  [.[] | select(any(.metadata.ownerReferences[]?; .kind == "ApplicationSet" and .name == $app_set))]
' <<< "$apps")
[[ $(jq 'length' <<< "$selected") -gt 0 ]] || die "No user-privacy applications found for $app_set"

if [[ "$mode" == rollouts ]]; then
  rollouts=$(jq -r '[.[] | .status.resources[]? | select(.group == "argoproj.io" and .kind == "Rollout") | .name] | unique[]' <<< "$selected")
  [[ -n "$rollouts" ]] || die "$app_set has no Rollout resources"
  printf '%s\n' "$rollouts"
  exit 0
fi

rollout="$3"
jq -e --arg rollout "$rollout" '
  all(.[]; any(.status.resources[]?; .group == "argoproj.io" and .kind == "Rollout" and .name == $rollout))
' <<< "$selected" >/dev/null || die "Rollout $rollout must exist in every application of $app_set; no promotions started"

targets=$(jq -r --arg rollout "$rollout" '
  sort_by(.metadata.name)[] | .metadata.name as $app |
  .status.resources[] | select(.group == "argoproj.io" and .kind == "Rollout" and .name == $rollout) |
  [$app, .namespace, .name] | @tsv
' <<< "$selected")

while IFS=$'\t' read -r app namespace resource; do
  command=("${argo[@]}" app actions run "$app" promote-full --kind Rollout --group argoproj.io --namespace "$namespace" --resource-name "$resource")
  printf '%q ' "${command[@]}"
  printf '\n'
  if [[ "$mode" == promote ]]; then
    "${command[@]}" || die "Promotion failed for $app/$resource; stopped, earlier promotions may have succeeded"
  fi
done <<< "$targets"
