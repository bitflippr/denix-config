{
  config,
  delib,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "polaris";

  nixos.ifEnabled = {
    boot = {
      binfmt.emulatedSystems = ["aarch64-linux"];
      kernelPackages = pkgs.linuxPackages_xanmod_latest;
      loader.systemd-boot.enable = true;

      initrd.availableKernelModules = [
        "nvme"
        "sd_mod"
        "uas"
        "usb_storage"
        "xhci_pci"
      ];

      kernelModules = [
        "e1000e"
        "i915"
        "kvm-intel"
      ];

      kernel.sysctl."vm.swappiness" = 100;
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_ROOT";
        fsType = "ext4";
      };

      "/boot" = {
        device = "/dev/disk/by-label/NIXOS_BOOT";
        fsType = "vfat";
        options = [
          "dmask=0022"
          "fmask=0022"
        ];
      };

      # The data SSD is on USB, and after a reboot it has taken 40 seconds to
      # enumerate. nofail keeps boot from waiting; only what needs /mnt does.
      "/mnt" = {
        device = "/dev/disk/by-label/POLARIS_DATA";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.device-timeout=3min"
        ];
      };
    };

    # Whatever requires /mnt and normally starts at boot also starts when it
    # mounts. A unit whose dependency failed stays inactive, not failed, so a
    # disk that turned up late used to leave these quietly down. Units with no
    # wantedBy (timer-run backups) are left alone.
    systemd.units =
      lib.mapAttrs' (name: _: lib.nameValuePair "${name}.service" {wantedBy = ["mnt.mount"];})
      (lib.filterAttrs (_: service: lib.elem "mnt.mount" service.requires && service.wantedBy != [])
        config.systemd.services);

    swapDevices = [
      {
        device = "/var/lib/swapfile";
        priority = 10;
        size = 32 * 1024;
      }
    ];

    zramSwap = {
      algorithm = "zstd";
      enable = true;
      memoryPercent = 25;
      priority = 100;
    };

    hardware = {
      cpu.intel.updateMicrocode = true;
      enableRedistributableFirmware = true;
      graphics.extraPackages = [pkgs.intel-media-driver];
    };
  };
}
