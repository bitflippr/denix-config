{
  delib,
  lib,
  ...
}: let
  # Two 1 TB Samsung NVMe drives. Everything that can't be regenerated lives on
  # the mirror; caches, build outputs and scratch space live on the stripe.
  disks = {
    a = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0X110569";
    b = "/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NF0WC12967";
  };

  disk = esp: device: {
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
          size = "500G";
          content = {
            type = "mdraid";
            name = "system";
          };
        };

        scratch = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "scratch";
          };
        };
      };
    };
  };
in
  delib.module {
    name = "argo";

    nixos.ifEnabled = {
      disko.devices = {
        disk = {
          a = disk "/boot" disks.a;
          b = disk "/boot-fallback" disks.b;
        };

        mdadm = {
          system = {
            type = "mdadm";
            level = 1;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = ["noatime"];
            };
          };

          scratch = {
            type = "mdadm";
            level = 0;
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/scratch";
              mountOptions = ["noatime"];
            };
          };
        };
      };

      boot = {
        swraid = {
          enable = true;
          mdadmConf = "MAILADDR root";
        };

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
