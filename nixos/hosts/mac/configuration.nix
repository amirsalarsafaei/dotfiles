# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, apple-silicon-support, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
        apple-silicon-support.nixosModules.default

    ];

  nixpkgs.overlays = [ apple-silicon-support.overlays.apple-silicon-overlay ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    binfmt.emulatedSystems = [ "x86_64-linux" ];
    extraModprobeConfig = ''
      options hid_apple swap_fn_leftctrl=1 iso_layout=0 swap_opt_cmd=1 '';
    m1n1CustomLogo = ./boot-logo.png;
    kernelParams = [ "apple_dcp.show_notch=1" ];
  };

  hardware = {
    asahi = {
      peripheralFirmwareDirectory = ./firmware;
      setupAsahiSound = true;
    };
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    shared-mime-info
    qemu
    dunst
    xdg-utils
    vim
    acpilight
    wget
    alacritty
    bind
    inetutils
    htop
    netcat
    tcpdump
    bluez
    zsh
    coreutils-full
    libimobiledevice
    ifuse
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    (sddm-astronaut.override{
      embeddedTheme = "japanese_aesthetic";
    })
    kdePackages.qtmultimedia
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;



  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.udev.extraRules = ''
    SUBSYSTEM=="backlight", ACTION=="add", RUN+="${pkgs.coreutils-full}/bin/chmod 666 /sys/class/backlight/apple-panel-bl/brightness", RUN+="${pkgs.coreutils-full}/bin/chmod 666 /sys/class/leds/kbd_backlight/brightness"
  '';

  services.k0s = {
    enable = false;
    role = "controller+worker";  # or "controller" or "worker"
    tokenFile = "/etc/k0s/k0stoken";
  };

  services.logind = {
    lidSwitch = "suspend";
  };
}
