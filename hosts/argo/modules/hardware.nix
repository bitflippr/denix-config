{
  delib,
  lib,
  ...
}: let
  # Two 1 TB Samsung NVMe drives. The system and the server's own state live on
  # a small btrfs mirror; home, agents' work, caches and builds get the rest of
  # both drives as a btrfs stripe, which the nightly backup covers.
  disks = {
    a = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0X110569";
    b = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0WC12967";
  };

  mountOptions = [
    "compress=zstd:1"
    "noatime"
  ];

  # One filesystem across both drives' partitions of this name, with its
  # metadata mirrored either way.
  btrfs = name: data: subvolumes: {
    type = "btrfs";
    extraArgs = ["-L" name "-d" data "-m" "raid1" "/dev/disk/by-partlabel/disk-a-${name}"];
    subvolumes = lib.mapAttrs (_: mountpoint: {inherit mountpoint mountOptions;}) subvolumes;
  };

  # Disko formats drives in name order and btrfs needs both halves present, so
  # drive a's halves stay bare and drive b creates each filesystem.
  disk = esp: device: filesystems: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = esp;
            mountOptions = ["umask=0077"];
          };
        };

        system = {
          size = "150G";
          content = filesystems.system or null;
        };

        work = {
          size = "100%";
          content = filesystems.work or null;
        };
      };
    };
  };
in
  delib.module {
    name = "argo";

    nixos.ifEnabled = {
      disko.devices.disk = {
        a = disk "/boot" disks.a {};
        b = disk "/boot-fallback" disks.b {
          system = btrfs "system" "raid1" {
            "/root" = "/";
            "/nix" = "/nix";
            "/log" = "/var/log";
          };

          work = btrfs "work" "raid0" {
            "/home" = "/home";
            "/scratch" = "/scratch";
          };
        };
      };

      # Mount by label, which both halves carry, so the mirror can still be
      # mounted degraded (rootflags=degraded) from whichever drive survives.
      fileSystems = lib.mapAttrs (_: label: {device = lib.mkForce "/dev/disk/by-label/${label}";}) {
        "/" = "system";
        "/nix" = "system";
        "/var/log" = "system";
        "/home" = "work";
        "/scratch" = "work";
      };

      # Checksums only help if something reads the data: monthly scrubs find bad
      # blocks early and repair the mirror's from the other drive.
      services.btrfs.autoScrub.enable = true;

      boot = {
        initrd.availableKernelModules = [
          "ahci"
          "nvme"
          "sd_mod"
          "usbhid"
          "xhci_pci"
        ];

        kernelModules = ["kvm-amd"];

        # One EFI system partition per drive, so either drive boots alone.
        loader = {
          efi.canTouchEfiVariables = false;
          grub = {
            enable = true;
            efiSupport = true;
            efiInstallAsRemovable = true;
            mirroredBoots = [
              {
                devices = ["nodev"];
                path = "/boot";
              }
              {
                devices = ["nodev"];
                path = "/boot-fallback";
              }
            ];
          };
        };
      };

      hardware = {
        cpu.amd.updateMicrocode = true;
        enableRedistributableFirmware = true;

        # The Ryzen 7700's Radeon iGPU renders headless agent desktops.
        graphics.enable = true;
      };

      zramSwap.enable = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
  }
