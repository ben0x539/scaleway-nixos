{ pkgs, config, ... }:

{
  imports = [
    ./scaleway-scripts/services.nix
    ./disable-stuff.nix
  ];

  services = {
    openssh.enable = true;
    fetch-ssh-keys.periodically = "1min";
  };

  system.build.installBootLoader = let
    initScript = pkgs.writeScript "scaleway-loader-init.sh" ''
      #! ${pkgs.stdenv.shell}
      set -euo pipefail

      cmdline=$(< /proc/cmdline)
      if [[ "$cmdline" == *is_in_kexec* ]]; then
        # probably shoudn't have gotten here
        echo >&2 "running /sbin/init kexec shim after kexec"
        exec /boot/init "$@"
        exit 1
      fi

      PATH=$PATH:${pkgs.coreutils}/bin:${pkgs.kexectools}/bin:${pkgs.scaleway-scripts}/bin

      pick_system() {
        system=''${TAG_NIXOS_SYSTEM:-}
        if [[ -n "$system" ]]; then
          echo "system selected by tag NIXOS_SYSTEM=$system"
          return
        fi
        local n=''${TAG_NIXOS_GENERATION:-}
        if [[ "$n" == -* ]]; then
          local latest
          latest=$(readlink /nix/var/nix/profiles/system)
          if ! [[ "$latest" == system-*-link ]]; then
            echo >&2 "/nix/var/nix/profiles/system == $latest - don't know what to do"
            exit 1
          fi
          echo "system selected by tag NIXOS_GENERATION=$n relative to latest=$latest"
          latest=''${latest#system-}
          latest=''${latest%-link}
          system=/nix/var/nix/profiles/system-$(( $latest + n ))-link
          return
        fi

        if [[ -n "$n" ]]; then
          echo "system selected by tag NIXOS_GENERATION=$n"
          system=/nix/var/nix/profiles/system-$n-link
        fi

        if [[ -L /boot/boot-this-once ]]; then
          system=$(readlink /boot/boot-this-once)
          rm /boot/boot-this-once
          echo "system selected by /boot/boot-this-once one-time symlink (deleted)"
          return
        fi
      }

      for idx in $(seq -w 0 $(scw-metadata --cached TAGS)); do
        tag=$(scw-metadata --cached TAGS_$idx)
        if [[ "$tag" == *=* ]]; then
          declare "TAG_''${tag%%=*}=''${tag#*=}"
        fi
      done

      pick_system

      if [[ -z "$system" ]]; then
        system=/boot
      fi


      for f in kernel initrd init; do
        if ! [[ -f "$system/$f" ]] ; then
            echo >&2 "$system/$f doesn't exist - don't know what to do"
            exit 1
        fi
      done

      echo "kexec'ing into $system"
      # todo: for baremetal, we might want to unmount nbd devices here, somehow
      kexec -lf \
        --initrd=$system/initrd \
        --append="$cmdline is_in_kexec=yes init=$system/init" \
        $system/kernel
    ''; in pkgs.writeScript "scaleway-install-fake-bootloader.sh" ''
      set -euo pipefail

      system=$1

      # the symlinks in the emitted system are absolute, but we want scaleway
      # to kexec them while we're mounted at /newroot, so we need relative
      # paths. set server tags to boot directly:
      #   KEXEC_KERNEL=/boot/kernel
      #   KEXEC_INITRD=/boot/initrd
      #   KEXEC_APPEND=init=/boot/init
      # todo: can we reasonably do that with the api from here?
      mkdir -p /boot
      ln -sfT ..$(readlink $system/kernel) /boot/kernel
      ln -sfT ..$(readlink $system/initrd) /boot/initrd
      ln -sfT ..$system/init /boot/init

      # we're too lazy to set tags all the time, so let's also put a script
      # at /sbin/init to be invoked by the scaleway initrd by default to kexec
      # directly, after scaleway passes control. this is kinda ugly because
      # it relies on scaleway's setup being somewhat compatible with nixos
      # stage2. on the other hand, we probably have network already.
      mkdir -p /sbin
      ln -sfT ${initScript} /sbin/init
    '';
}
