{ pkgs, config, ... }:

{
  imports = [
    ./scaleway.nix
  ];

  fileSystems = [
    {
      mountPoint = "/";
      device = "/dev/vda";
      options = [ "relatime" ];
    }
  ];

  environment.systemPackages = with pkgs; [
    screen
    vim
  ];

  boot.initrd.kernelModules = [ "virtio_blk" "virtio_pci" "virtio_scsi" "ext4" ];

  # Build faster!
  nix.buildCores = 8;
  nix.maxJobs = 8;

  nixpkgs.config.allowUnfree = true;
}
