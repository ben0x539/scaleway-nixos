{ pkgs, config, ... }:

{
  imports = [
    ./scaleway-scripts/services.nix
    ./disable-stuff.nix
  ];

  services = {
    openssh.enable = true;
  };

  system.build.installBootLoader = pkgs.writeScript "make-kernel-initrd-symlinks.sh" ''
    mkdir -p /boot
    out="$1"
    ln -sfT ..$(readlink $out/kernel) /boot/kernel
    ln -sfT ..$(readlink $out/initrd) /boot/initrd
  '';

  fileSystems = [
    {
      mountPoint = "/";
      device = "/dev/nbd0";
      options = [ "relatime" ];
    }
  ];

  environment.systemPackages = with pkgs; [
    screen
    vim
  ];

  # Build faster!
  nix.buildCores = 4;
  nix.maxJobs = 4;
}
