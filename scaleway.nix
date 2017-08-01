{ pkgs, config, ... }:

{
  imports = [
    ./scaleway-scripts/services.nix
    ./disable-stuff.nix
  ];

  services = {
    openssh.enable = true;
    load-ssh-keys.enable = true;
  };

  system.build.installBootLoader = pkgs.writeScript "make-kernel-initrd-symlinks.sh" ''
    mkdir -p /boot
    out="$1"
    ln -sfT ..$(readlink $out/kernel) /boot/kernel
    ln -sfT ..$(readlink $out/initrd) /boot/initrd
  '';
}
