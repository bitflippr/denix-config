{
  delib,
  pkgs,
  ...
}:
# Waydroid on the NVIDIA GPU (pkgs.local.waydroid-nvidia). After a rebuild, and
# again after every NVIDIA driver update, run `sudo waydroid-nvidia-setup`: it
# initializes Waydroid if needed, gates the release's vendor image on the loaded
# kernel module and installs it. The container refuses to start until it has.
delib.module {
  name = "system.waydroidNvidia";

  options.system.waydroidNvidia = with delib; {
    enable = boolOption false;
  };

  nixos.ifEnabled = let
    package = pkgs.local.waydroid-nvidia;
    # == dev/source-native render_override(): the drop-in upstream writes to
    # /etc/systemd/system, declared here because that directory is read-only.
    renderUnit = "sys-subsystem-waydroid_nvidia-render.device";
  in {
    virtualisation.waydroid = {
      enable = true;
      package = package.waydroid;
    };

    environment.systemPackages = [package];

    # 70-waydroid-nvidia-gpu.rules names the NVIDIA render node ${renderUnit};
    # 70-waydroid-nvidia.rules gives the seat user /dev/udmabuf (venus mode).
    services.udev.packages = [package];

    systemd = {
      tmpfiles.rules = [
        # Upstream's tools and the patched Waydroid locate the release here.
        "L+ /usr/lib/waydroid-nvidia - - - - ${package}/lib/waydroid-nvidia"
        "d /run/waydroid-venus 1777 root root -"
      ];

      services.waydroid-container = {
        wants = [renderUnit];
        after = [renderUnit];
        path = package.runtimeDeps;
        # Nothing to start before `waydroid-nvidia-setup` has initialized Waydroid.
        unitConfig.ConditionPathExists = "/var/lib/waydroid/waydroid.cfg";
        serviceConfig.ExecStartPre = "${pkgs.python3.interpreter} ${package}/lib/waydroid-nvidia/native/dev/driver-mode verify-active";
      };
    };
  };
}
