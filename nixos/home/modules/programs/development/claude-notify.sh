input=$(cat)
topic="${CLAUDE_NOTIFY_TOPIC:?claude-notify: CLAUDE_NOTIFY_TOPIC unset}"
terminal_classes=(com.mitchellh.ghostty kitty)

field() {
  jq -r --arg key "$1" '.[$key] // empty | tostring | .[0:400]' <<<"$input"
}

event=$(field hook_event_name)
case "$event" in
  Stop)
    state="finished"
    tags="white_check_mark"
    priority="default"
    detail=$(field last_assistant_message)
    ;;
  StopFailure)
    state="failed"
    tags="x"
    priority="high"
    detail=$(field error_details)
    [[ -n $detail ]] || detail=$(field error)
    ;;
  Notification)
    case "$(field notification_type)" in
      permission_prompt)
        state="needs permission"
        tags="warning"
        priority="high"
        ;;
      elicitation_dialog)
        state="has a question"
        tags="question"
        priority="high"
        ;;
      *) exit 0 ;;
    esac
    detail=$(field message)
    ;;
  *) exit 0 ;;
esac

pane='{}'
if [[ -n ${ZELLIJ_SESSION_NAME:-} && -n ${ZELLIJ_PANE_ID:-} ]]; then
  pane=$(zellij action list-panes --json --state 2>/dev/null |
    jq -c --arg id "$ZELLIJ_PANE_ID" \
      'first(.[] | select((.is_plugin | not) and (.id | tostring) == $id)) // {}') || pane='{}'
  [[ -n $pane ]] || pane='{}'
fi

is_terminal() {
  local class
  for class in "${terminal_classes[@]}"; do
    [[ $1 == "$class" ]] && return 0
  done
  return 1
}

is_ancestor() {
  local pid=$$
  while [[ -n $pid && $pid -gt 1 ]]; do
    [[ $pid == "$1" ]] && return 0
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ') || return 1
  done
  return 1
}

is_watching() {
  local active
  command -v hyprctl >/dev/null || return 1
  active=$(hyprctl activewindow -j 2>/dev/null) || return 1
  is_terminal "$(jq -r '.class // empty' <<<"$active")" || return 1

  if [[ -n ${ZELLIJ_SESSION_NAME:-} ]]; then
    [[ $(jq -r '.title // empty' <<<"$active") == "$ZELLIJ_SESSION_NAME | "* ]] || return 1
    [[ $(jq -r '.is_focused // false' <<<"$pane") == true ]]
    return
  fi

  is_ancestor "$(jq -r '.pid // empty' <<<"$active")"
}

if is_watching; then
  exit 0
fi

variant="${CLAUDE_VARIANT_NAME:-claude}"
case "$variant" in
  gap-claude) emoji="🌐" ;;
  glm-claude) emoji="🌙" ;;
  *deepseek-claude) emoji="🐋" ;;
  work-claude) emoji="💼" ;;
  local-claude) emoji="🏠" ;;
  *) emoji="🤖" ;;
esac

cwd=$(field cwd)
where="${cwd##*/}"
[[ -n $where ]] || where="$variant"
tab=$(jq -r '.tab_name // empty' <<<"$pane")
pane_title=$(jq -r '.title // empty' <<<"$pane")
[[ -n $tab ]] && where+=" · tab: $tab"
[[ -n $pane_title ]] && where+=" · pane: $pane_title"

body="$where"
[[ -n $detail ]] && body+=$'\n\n'"$detail"

ntfy --quiet \
  --topic "$topic" \
  --title "$emoji $variant $state" \
  --tags "$tags" \
  --priority "$priority" \
  "$body" || true
