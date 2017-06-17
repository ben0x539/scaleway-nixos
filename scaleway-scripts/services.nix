{ pkgs, config, lib,  ... }:

with lib;

let
  sshCfg = config.services.load-ssh-keys;
in

{
  options = {
    services.load-ssh-keys = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to load root's .ssh/authorized_keys from Scaleway at startup.
        '';
      };
    };
  };

  config = {
    nixpkgs.overlays = [ (self: super: {
      scaleway-scripts = self.callPackage ./. {};
    }) ];

    environment.systemPackages = with pkgs; [
      scaleway-scripts
    ];

    systemd.services.load-ssh-keys = mkIf sshCfg.enable {
      description = "Load root's .ssh/authorized_keys from Scaleway servers";
      before = [ "sshd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type="oneshot";
        ExecStart="${pkgs.scaleway-scripts}/bin/oc-fetch-ssh-keys";
      };
    };
  };
}
