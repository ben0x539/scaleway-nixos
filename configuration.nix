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

  users.users.nix_remote = {
    name = "nix_remote";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPh6Ri5HiQjH5bgpKyyDRnLqg2omvy7DkBWIdsMEFJ4e ben@vigil"
    ];
  };

  # Build faster!
  nix.buildCores = 8;
  nix.maxJobs = 8;
}
