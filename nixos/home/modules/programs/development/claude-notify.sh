input=$(cat)
topic="${CLAUDE_NOTIFY_TOPIC:?claude-notify: CLAUDE_NOTIFY_TOPIC unset}"
terminal_classes=(com.mitchellh.ghostty kitty)

field() {
  jq -r --arg key "$1" '.[$key] // empty | tostring | .[0:400]' <<<"$input"
}

event=$(field hook_event_name)
case "$event" in
  Stop)
    tags="white_check_mark"
    priority="default"
    ;;
  StopFailure)
    tags="x"
    priority="high"
    ;;
  Notification)
    case "$(field notification_type)" in
      permission_prompt)
        tags="warning"
        priority="high"
        ;;
      elicitation_dialog)
        tags="question"
        priority="high"
        ;;
      *) exit 0 ;;
    esac
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

ntfy --quiet \
  --topic "$topic" \
  --title "$emoji $variant" \
  --tags "$tags" \
  --priority "$priority" \
  "requires your input" || true
