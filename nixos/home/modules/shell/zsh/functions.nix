{ funFortunes, flagPluginsZshArgs }:
{
  gavgo = "fortune ${funFortunes} | cowsay | lolcat";

  "_claude-common" = ''
    #compdef gap-claude local-claude

    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '--chrome[attach playwright-mcp --extension (control your logged-in Chrome via the Playwright Extension, one tab group per session, approve each connection)]' \
      '--sec-chrome[attach chrome-devtools-mcp (DevTools inspection + network/console capture)]' \
      '--playwright[attach playwright-mcp]' \
      '--no-sandbox[skip the bubblewrap sandbox for this launch]' \
      '--sandbox-net[unshare the network namespace for this launch]' \
      '--sandbox-fs[restrict the sandbox home to \$PWD and the config dir]' \
      ${flagPluginsZshArgs} \
      '*:: :_default'
  '';

  "_claude-mcp" = ''
    #compdef work-claude glm-claude deepseek-claude kimi-claude personal-deepseek-claude personal-claude claude

    _arguments \
      '--effort[effort level for this session]:level:(low medium high xhigh max)' \
      '--agentic-mcps[attach agentic-development-mcps for this launch]' \
      '--gitlab-mcp[allow the gitlab_* tool family on agentic-development-mcps]' \
      '--nixos[attach mcp-nixos (nixpkgs/NixOS/Home Manager/nix-darwin search)]' \
      '--search[attach the DeepSeek Search & Fetch MCP server (deepseek variants only)]' \
      '--chrome[attach playwright-mcp --extension (control your logged-in Chrome via the Playwright Extension, one tab group per session, approve each connection)]' \
      '--sec-chrome[attach chrome-devtools-mcp (DevTools inspection + network/console capture)]' \
      '--playwright[attach playwright-mcp]' \
      '--no-sandbox[skip the bubblewrap sandbox for this launch]' \
      '--sandbox-net[unshare the network namespace for this launch]' \
      '--sandbox-fs[restrict the sandbox home to \$PWD and the config dir]' \
      ${flagPluginsZshArgs} \
      '*:: :_default'
  '';
}
