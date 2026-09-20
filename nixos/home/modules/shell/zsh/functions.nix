{ funFortunes, flagPluginsZshArgs }:
{
  gavgo = "fortune ${funFortunes} | cowsay | lolcat";

  divar-warm = ''
    if ssh -O check git@git.divar.cloud >/dev/null 2>&1; then
      return 0
    fi
    echo "Warming git.divar.cloud SSH connection..." >&2
    ssh -fNT git@git.divar.cloud
  '';

  # flagPluginsZshArgs is generated from custom.claudeCode.flagPlugins (see
  # home/modules/programs/development/claude-code.nix) — every claude variant
  # wrapper accepts those flags (e.g. --crit, --no-devar) to toggle a plugin
  # for one launch, and this keeps completion in sync with zero extra edits.
  "_claude-common" = ''
    #compdef gap-claude local-claude

    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '--chrome[attach chrome-devtools-mcp (DevTools inspection + browser automation)]' \
      '--playwright[attach playwright-mcp]' \
      '--no-sandbox[skip the bubblewrap sandbox for this launch]' \
      '--sandbox-net[unshare the network namespace for this launch]' \
      '--sandbox-fs[restrict the sandbox home to \$PWD and the config dir]' \
      ${flagPluginsZshArgs} \
      '*:: :_default'
  '';

  "_claude-mcp" = ''
    #compdef work-claude glm-claude deepseek-claude personal-deepseek-claude personal-claude claude

    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '--agentic-mcps[attach agentic-development-mcps for this launch]' \
      '--gitlab-mcp[allow the gitlab_* tool family on agentic-development-mcps]' \
      '--nixos[attach mcp-nixos (nixpkgs/NixOS/Home Manager/nix-darwin search)]' \
      '--chrome[attach chrome-devtools-mcp (DevTools inspection + browser automation)]' \
      '--playwright[attach playwright-mcp]' \
      '--no-sandbox[skip the bubblewrap sandbox for this launch]' \
      '--sandbox-net[unshare the network namespace for this launch]' \
      '--sandbox-fs[restrict the sandbox home to \$PWD and the config dir]' \
      ${flagPluginsZshArgs} \
      '*:: :_default'
  '';
}
