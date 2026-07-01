{ lib
, pkgs
, hostname
, ...
}:
let
  dataPython = pkgs.python312.withPackages (
    ps: with ps; [
      matplotlib
      numpy
      pandas
    ]
  );

  pythonData = pkgs.stdenvNoCC.mkDerivation {
    pname = "python-data";
    version = pkgs.python312.version;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${dataPython}/bin/python $out/bin/python-data
      ln -s ${dataPython}/bin/python3 $out/bin/python-data3
    '';
  };
in
{
  networking.hostName = lib.mkDefault hostname;
  time.timeZone = lib.mkDefault "Asia/Tehran";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  environment.systemPackages = [
    pkgs.tzdata
    pythonData
  ];

  programs.zsh.enable = lib.mkDefault true;

  zramSwap.enable = lib.mkDefault true;

  nix.settings = {
    experimental-features = lib.mkDefault [
      "nix-command"
      "flakes"
    ];
    trusted-users = lib.mkDefault [
      "root"
      "@wheel"
    ];
  };

  systemd.services.nix-cleanup = {
    description = "NixOS generation cleanup";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "nix-cleanup" ''
        ${pkgs.nix}/bin/nix-env --delete-generations 30d --profile /nix/var/nix/profiles/system
        ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 30d
      ''}";
    };
  };

  systemd.timers.nix-cleanup = {
    wantedBy = [ "timers.target" ];
    partOf = [ "nix-cleanup.service" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
