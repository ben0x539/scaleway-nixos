{ pkgs, config, ... }:

{
  imports = [
    ./scaleway-scripts/services.nix
    ./disable-stuff.nix
  ];

  services = {
    openssh.enable = true;
  };

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
