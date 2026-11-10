usage() {
  cat <<'EOF'
Usage: secret {set|get|delete} TYPE ID

Types: api-key, token, password
ID: lowercase words or numbers separated by single hyphens.

  secret set api-key glm-claude
  secret get api-key glm-claude
  secret delete api-key glm-claude

set prompts for a hidden value, or reads it from stdin when piped.
Entries use the secret-tool attributes: type TYPE id ID.
EOF
}

if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
  usage
  exit 0
fi

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 2
fi

action=$1
type=$2
id=$3

case "$type" in
  api-key|token|password) ;;
  *)
    printf 'secret: invalid type %s; use api-key, token, or password\n' "$type" >&2
    exit 2
    ;;
esac

if [[ ! $id =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  printf 'secret: ID must be lowercase words or numbers separated by single hyphens\n' >&2
  exit 2
fi

case "$action" in
  set)
    exec secret-tool store --label="$id ($type)" type "$type" id "$id"
    ;;
  get)
    exec secret-tool lookup type "$type" id "$id"
    ;;
  delete)
    exec secret-tool clear type "$type" id "$id"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
