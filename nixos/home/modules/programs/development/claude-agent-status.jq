def flat: (. // "") | tostring | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");
def clip($n): if length > $n then .[0:$n - 1] + "…" else . end;
def base: (. // "") | tostring | sub("/+$"; "") | split("/") | last // "";
def act($verb; $object): {verb: $verb, object: ($object | flat | clip(64))};

def activity:
  (.tool_input // {}) as $in
  | (.tool_name // "") as $tool
  | if $tool == "Bash" then act("run"; $in.description // ($in.command // "" | split("\n") | first))
    elif $tool == "Read" then act("read"; $in.file_path | base)
    elif $tool == "Edit" or $tool == "MultiEdit" or $tool == "Write" then act(if $tool == "Write" then "write" else "edit" end; $in.file_path | base)
    elif $tool == "NotebookEdit" then act("edit"; $in.notebook_path | base)
    elif $tool == "Grep" or $tool == "Glob" then act("search"; $in.pattern)
    elif $tool == "WebFetch" then act("fetch"; $in.url // "" | sub("^[a-z]+://"; "") | split("/") | first)
    elif $tool == "WebSearch" then act("search web"; $in.query)
    elif $tool == "Agent" or $tool == "Task" then act("delegate"; $in.description)
    elif $tool == "Skill" then act("skill"; $in.skill)
    elif $tool == "TodoWrite" then act("plan"; "")
    elif $tool == "AskUserQuestion" then act("ask"; $in.questions[0].question // "")
    elif $tool == "EnterPlanMode" then act("plan"; "")
    elif $tool == "ExitPlanMode" then act("plan"; "ready for review")
    elif $tool | startswith("mcp__") then
      ($tool | split("__")) as $parts
      | act($parts[1] // "mcp" | sub("^plugin_[^_]+_"; "") | sub("^claude_ai_"; "") | gsub("_"; " ") | ascii_downcase; $parts[2:] | join(" ") | gsub("_"; " "))
    else act($tool | ascii_downcase; "")
    end;

def todos:
  (.tool_input.todos // []) as $list
  | {
      done: ([$list[] | select(.status == "completed")] | length),
      total: ($list | length),
      current: ([$list[] | select(.status == "in_progress") | .activeForm // .content] | first // "" | flat | clip(96))
    };

($cur[0] // {}) as $raw
| (if ($raw | type) == "object" then $raw else {} end) as $all
| (.session_id // "") as $id
| (.hook_event_name // "") as $event
| if $id == "" then $all
  elif $event == "SessionEnd" then $all | del(.[$id])
  else
    ($all[$id] // {started: $now, tools: 0, agents: 0, state: "idle", since: $now}) as $old
    | (.cwd // $old.cwd // "") as $cwd
    | ($old + {at: $now, variant: $variant, realm: $realm, cwd: $cwd, project: ($cwd | base), mode: (.permission_mode // $old.mode // "default")}
        + (if $zsession != "" and $zpane != "" then {zellij: {session: $zsession, pane: $zpane}} else {} end)
        + (if (.session_title | flat | length) > 0 then {title: (.session_title | flat | clip(96))} else {} end)) as $base
    | (if $event == "SessionStart" then
         $base
         + (if .source == "clear" then {title: null, prompt: null, todo: null, tools: 0, verb: "", object: ""} else {} end)
         + (if .source == "compact" then {} else {state: "idle", since: $now} end)
       elif $event == "UserPromptSubmit" then
         $base + {state: "working", since: $now, verb: "think", object: ""}
         + (if (.prompt | flat | length) > 0 then {prompt: (.prompt | flat | clip(96))} else {} end)
       elif $event == "PreToolUse" then
         (if .tool_name == "AskUserQuestion" or .tool_name == "ExitPlanMode" then "waiting" else "working" end) as $state
         | $base + activity + {state: $state, tools: (($old.tools // 0) + 1)}
         + (if $old.state != $state then {since: $now} else {} end)
         + (if .tool_name == "TodoWrite" then {todo: todos} else {} end)
         + (if .tool_name == "EnterPlanMode" then {mode: "plan"} else {} end)
       elif $event == "PostToolUse" or $event == "PostToolUseFailure" then
         $base + (if $old.state == "waiting" then {state: "working", since: $now} else {} end)
       elif $event == "Notification" then
         if (.notification_type // "" | test("permission_prompt|elicitation|needs_input")) then
           $base + {state: "waiting", since: $now}
         else $base end
       elif $event == "SubagentStart" then $base + {agents: (($old.agents // 0) + 1)}
       elif $event == "SubagentStop" then $base + {agents: ([($old.agents // 0) - 1, 0] | max)}
       elif $event == "PreCompact" then $base + {verb: "compact", object: ""}
       elif $event == "Stop" then $base + {state: "idle", since: $now, verb: "done", object: "", agents: 0}
       elif $event == "StopFailure" then $base + {state: "error", since: $now, verb: "failed", object: (.error | flat | clip(64)), agents: 0}
       else $base
       end) as $next
    | (if $next.zellij == null then $all else $all | with_entries(select(.key == $id or .value.zellij != $next.zellij)) end)
      + {($id): $next}
  end
| with_entries(select($now - (.value.at // 0) < 43200000))
