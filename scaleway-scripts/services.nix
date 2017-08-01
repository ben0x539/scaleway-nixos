{ pkgs, config, lib,  ... }:

with lib;

let
  sshCfg = config.services.fetch-ssh-keys;
  nbdCfg = config.boot.initrd.get-nbd-volumes;
in

{
  options = {
    services.fetch-ssh-keys = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to fetch root's .ssh/authorized_keys from Scaleway at startup.
        '';
      };
      periodically = mkOption {
        type = types.nullOr types.string;
        description = ''
          Update /root/.ssh/authorized_keys periodically.
        '';
        default = null;
      };
    };
    boot.initrd.get-nbd-volumes = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to attach and mount nbd volumes from Scaleway metadata.
        '';
      };
    };
  };

  config = {
    nixpkgs.overlays = [ (self: super: {
      scaleway-scripts = self.callPackage ./. {};
    }) ];

    environment.systemPackages = with pkgs; mkIf (sshCfg.enable || nbdCfg.enable) [
      scaleway-scripts
    ];

    systemd.services.fetch-ssh-keys = mkIf sshCfg.enable {
      description = "Fetch root's .ssh/authorized_keys from Scaleway servers";
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "sshd.service" ];
      serviceConfig = {
        Type="oneshot";
        ExecStart="${pkgs.scaleway-scripts}/bin/scw-fetch-ssh-keys";
      };
    };
    services.fetch-ssh-keys.enable = mkIf (sshCfg.periodically != null) true;
    systemd.timers.fetch-ssh-keys = mkIf (sshCfg.periodically != null) {
      description = "Update /root/.ssh/authorized_keys periodically";
      timerConfig = {
        OnUnitActiveSec="${sshCfg.periodically}";
        RandomizedDelaySec="15s";
        AccuracySec="5s";
      };
      wantedBy = [ "fetch-ssh-keys.service" ];
    };

    # TODO: bare-metal needs the ndb stuff + networking in initrd,
    # vms probably just need virtio_blk and ext4 to mount /dev/vda
    boot.initrd = mkIf nbdCfg.enable {
      extraUtilsCommands = ''
        copy_bin_and_libs ${pkgs.scaleway-scripts}/bin/scw-metadata
        copy_bin_and_libs ${pkgs.nbd}/bin/nbd-client
        copy_bin_and_libs ${pkgs.mkinitcpio-nfs-utils}/bin/ipconfig
      '';
      kernelModules = [ "nbd" "af_packet" "virtio_blk" "virtio_pci" "virtio_net" "virtio_scsi" "8021q" "fixed_phy" "mvmdio" "igb" "igbvf" "ext4" ];
      preDeviceCommands = let

        udhcpcScript = pkgs.writeScript "udhcp-script"
          ''
            #! /bin/sh
            if [ "$1" = bound ]; then
              ip address add "$ip/$mask" dev "$interface"
              if [ -n "$router" ]; then
                ip route add default via "$router" dev "$interface"
              fi
              if [ -n "$dns" ]; then
                rm -f /etc/resolv.conf
                for i in $dns; do
                  echo "nameserver $dns" >> /etc/resolv.conf
                done
              fi
            fi
          '';

      in ''
        # TODO: this doesn't work, we don't get network devices. :'(
        # nixos/modules/system/boot/initrd-networking.nix, but earlier
        #
        # Bring up all interfaces.
        for iface in $(cd /sys/class/net && ls); do
          echo "bringing up network interface $iface..."
          ip link set "$iface" up
        done

        # Acquire a DHCP lease.
        echo "acquiring IP address via DHCP..."
        udhcpc --quit --now --script ${udhcpcScript} && hasNetwork=1

        # logic taken from https://github.com/scaleway/initrd/blob/94f40b68de094c0f335a09f2ce5b80f2b53aceda/Linux/tree-common/functions#L241
        #
        wget --proxy=off --quiet --output-document=- \
            http://169.254.42.42/conf \
          | grep "^VOLUMES_.*_EXPORT_URI=nbd://" \
          | while IFS= read -r nbd_info; do
          nbd_info="''${nbd_info#VOLUMES_}"
          nbd_dev="/dev/nbd''${nbd_info%%_*}"
          if nbd-client -c "$nbd_dev" >/dev/null 2>&1; then
            continue
          fi
          nbd_addr="''${nbd_info#*_EXPORT_URI=nbd://}"
          nbd_host="''${nbd_addr%%:*}"
          nbd_port="''${nbd_addr#*:}"
          nbd-client --blocksize=4096 --retries=900 \
            "$nbd_host" "$nbd_port" "$nbd_dev"
          if ! nbd_pid=$(nbd-client --check "$nbd_dev" 2>/dev/null); then
            echo >&2 "failed to connect $nbd_dev to $nbd_addr"
            continue
          fi
          echo -1000 >/proc/$nbd_pid/oom_score_adj
          if grep -q '\[cfq\]' "/sys/block/$nbd_dev/queue/scheduler"; then
            echo deadline > "/sys/block/$nbd_dev/queue/scheduler"
          fi
        done
      '';
    };
  };
}
