{ pkgs, ... }:

{
  # Avoid pulling in all of X.
  environment.noXlibs = true;
  boot.loader.grub.enable = false;
  system.build.installBootLoader = "${pkgs.coreutils}/bin/true";
  powerManagement.enable = false;
  systemd.services."systemd-vconsole-setup".enable = false;
  sound.enable = false;
  fonts.fontconfig.enable = false;
  services.nixosManual.enable = false;
  networking = {
    # can't enable: iptables v1.6.1: can't initialize iptables table `filter': Table does not exist (do you need to insmod?)
    firewall.enable = false;

    # can't rename, device or resource busy
    usePredictableInterfaceNames = false;
  };
}
