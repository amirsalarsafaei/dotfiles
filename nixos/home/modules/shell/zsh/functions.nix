{ funFortunes }:
{
  gavgo = "fortune ${funFortunes} | cowsay | lolcat";

  divar-warm = ''
    if ssh -O check git@git.divar.cloud >/dev/null 2>&1; then
      return 0
    fi
    echo "Warming git.divar.cloud SSH connection..." >&2
    ssh -fNT git@git.divar.cloud
  '';

  # --effort is common to every claude-code wrapper (see effortParserText in
  # programs/development/claude-code.nix); levels match what `claude --help`
  # lists. gap-claude and normal-claude have no agentic-development-mcps
  # wiring, so no --mcp-groups here — see _claude-mcp below for the variants
  # that do.
  "_claude-common" = ''
    #compdef gap-claude normal-claude local-claude

    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '*:: :_default'
  '';

  # claude-work and glm-claude both exec with --mcp-config pointed at the
  # agentic-development-mcps server (see workMcpConfigPath in
  # programs/development/claude-code.nix); the `claude` picker forwards args
  # verbatim to whichever variant gets picked, so it gets the same completion
  # even though gap/normal would reject --mcp-groups if chosen instead. Keep
  # the group list in sync with workMcpGroups in claude-code.nix.
  "_claude-mcp" = ''
    #compdef claude-work glm-claude claude

    local curcontext="$curcontext" state line
    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '--mcp-groups[agentic-development-mcps tool groups to keep enabled, comma-separated]:groups:->mcpgroups' \
      '*:: :_default'

    case $state in
      mcpgroups)
        _values -s , 'mcp group' tempo metrics logs pyroscope codesearch sandboxing outline mattermost
        ;;
    esac
  '';
}
