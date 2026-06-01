{
  config,
  inputs,
  ...
}:
let
  username = config.custom.user.name;
  user = config.users.users.${username};
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.etc."xdg/nvim".source = inputs.dotfiles + "/nvim";
  environment.etc."xdg/nvim-host.lua".text = ''
    return {
      ai = true,
      wakatime = true,
    }
  '';

  systemd.tmpfiles.rules = [
    "d ${user.home}/.config 0755 ${username} ${user.group} -"
    "L+ ${user.home}/.config/nvim - - - - /etc/xdg/nvim"
    "L+ ${user.home}/.config/nvim-host.lua - - - - /etc/xdg/nvim-host.lua"
  ];
}
