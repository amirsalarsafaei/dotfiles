{ osConfig, lib, ... }:
let
  isLaptop = osConfig.isLaptop or false;
in
{
  services.batsignal = lib.mkIf isLaptop {
    enable = true;
    extraArgs = [
      "-w"
      "20"
      "-c"
      "10"
      "-d"
      "5"
    ];
  };
}
