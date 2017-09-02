{ ... }:

{
  imports = [ ../configuration.nix ];

  users = {
    mutableUsers = false;
    users = {
      nix_remote = {
        useDefaultShell = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPh6Ri5HiQjH5bgpKyyDRnLqg2omvy7DkBWIdsMEFJ4e ben@vigil"
        ];
      };
      ben = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6mwL5C9hGn0FYdHQL3Xdk2Pmd8+ZUPC//gf9FOGk4m ben@vigil"
        ];
      };
    };
  };
  security.sudo.wheelNeedsPassword = false;
}
