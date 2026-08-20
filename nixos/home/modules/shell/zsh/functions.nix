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

  "_claude-common" = ''
    #compdef gap-claude local-claude

    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '*:: :_default'
  '';

  "_claude-mcp" = ''
    #compdef work-claude glm-claude normal-claude claude

    local curcontext="$curcontext" state line
    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '--mcp-groups[agentic-development-mcps tool groups to keep enabled, comma-separated]:groups:->mcpgroups' \
      '--agentic-mcps[attach agentic-development-mcps for this launch]' \
      '--gitlab-mcp[allow the gitlab_* tool family on agentic-development-mcps]' \
      '*:: :_default'

    case $state in
      mcpgroups)
        _values -s , 'mcp group' tempo metrics logs pyroscope codesearch sandboxing outline mattermost
        ;;
    esac
  '';
}
