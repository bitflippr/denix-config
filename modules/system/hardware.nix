{
  delib,
  pkgs,
  config,
  lib,
  ...
}:
delib.module {
  name = "system.hardware";

  options.system.hardware = with delib; {
    enable = boolOption false;
  };

  nixos.ifEnabled = {myconfig, ...}: {
    hardware =
      {
        bluetooth.enable = true;

        graphics = {
          enable = true;
          enable32Bit = true;
        };
      }
      // lib.optionalAttrs myconfig.host.isDesktop {
        i2c.enable = true;
        nvidia-container-toolkit.enable = true;

        graphics.extraPackages = with pkgs; [
          libva-vdpau-driver
          nvidia-vaapi-driver
        ];

        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.bleeding_edge;
          modesetting.enable = true;
          powerManagement.enable = false;
          open = true;
        };
      };

    # A driver upgrade swaps in new userspace libraries while the previous
    # kernel module is still loaded, so regenerating the CDI spec during
    # activation can only fail with "Driver/library version mismatch". Keep the
    # spec from the running generation and let the unit regenerate it at boot,
    # where the module and the libraries match again.
    systemd.services = lib.mkIf myconfig.host.isDesktop {
      nvidia-container-toolkit-cdi-generator.restartIfChanged = false;
    };
  };
}
