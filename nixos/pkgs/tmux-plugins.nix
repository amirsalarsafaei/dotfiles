{
  tmuxPlugins,
  fetchFromGitHub,
}:
{
  battery = tmuxPlugins.mkTmuxPlugin {
    pname = "battery";
    pluginName = "battery";
    version = "2023-12-01";
    src = fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tmux-battery";
      rev = "48fae59ba4503cf345d25e4e66d79685aa3ceb75";
      sha256 = "1gx5f6qylzcqn6y3i1l92j277rqjrin7kn86njvn174d32wi78y8";
    };
  };
}
