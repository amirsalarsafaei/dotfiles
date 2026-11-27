{ funFortunes, commonFlagsZshArgs }:
{
  gavgo = "fortune ${funFortunes} | cowsay | lolcat";

  "_claude-common" = ''
    #compdef gap-claude local-claude

    _arguments \
      ${commonFlagsZshArgs} \
      '*:: :_default'
  '';

  "_claude-mcp" = ''
    #compdef work-claude glm-claude deepseek-claude kimi-claude personal-deepseek-claude orca-claude personal-claude claude

    _arguments \
      ${commonFlagsZshArgs} \
      '--agentic-mcps[attach agentic-development-mcps for this launch]' \
      '--gitlab-mcp[allow the gitlab_* tool family on agentic-development-mcps]' \
      '--nixos[attach mcp-nixos (nixpkgs/NixOS/Home Manager/nix-darwin search)]' \
      '--orca-model[run this model id, skipping the picker (orca-claude only)]:model:' \
      '--search[attach the DeepSeek Search & Fetch MCP server (deepseek variants only)]' \
      '*:: :_default'
  '';
}
