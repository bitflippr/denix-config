{delib, ...}:
# What `fleet where` tells agents about Polaris. Keep it to what an agent
# needs to work here without asking; the fleet notes hold the history.
delib.module {
  name = "polaris";

  nixos.ifEnabled.programs.fleet = {
    enable = true;
    broker = {
      enable = true;
      users = ["marshall"];
    };

    host = {
      role = "Mars's home server: the homelab (Jellyfin and the *arr apps, Forgejo, Vaultwarden, Home Assistant, PDS, Zipline, Glance and more) and the win11 and rovefs-fedora Incus VMs. Most agent work runs on argo; work here when it needs Polaris's services, VMs or data.";
      owner = "Mars (they/them)";

      conventions = [
        "The homelab serves Mars and their household. Don't stop, restart or reconfigure a service or VM unless the task is about it."
        "/ has little free space. Put builds, caches, downloads and job output on /mnt; /mnt/scratch is for agent work."
        "This is NixOS: get tools with `nix shell nixpkgs#<pkg>`. Polaris's config is denix-config hosts/polaris. Make changes in argo's checkout (~/Projects/denix-config on argo) and push; ~/nix-config here pulls them."
        "To switch Polaris, pull ~/nix-config (`git -C ~/nix-config pull --ff-only`) and run `fleet switch --reason WHY` in it: it builds as you and asks Mars to activate the build. Never run nixos-rebuild over SSH; a tailscaled restart kills the session mid-switch."
        "Use `fleet job run` for anything that may outlive a tool call. Remove files with `rip`, not rm."
        "There's no python3 here; use node to parse JSON. Over SSH the login shell is fish, so wrap bash syntax in `bash -c`."
      ];

      paths = {
        scratch = "/mnt/scratch";
        projects = "/home/marshall/Projects";
        config = "/home/marshall/nix-config";
        fleet-notes = "/home/marshall/Projects/agent-fleet";
      };

      mounts = {
        "/" = "ext4 on the NVMe: system, Nix store, home; nearly full";
        "/mnt" = "ext4 on the 2 TB data SSD (POLARIS_DATA): media, Incus VMs, app data, agent scratch";
      };

      # `fleet job run` refuses new jobs below these.
      disk_floor = {
        "/" = "8G";
        "/mnt" = "100G";
      };

      caches = {
        "/mnt/scratch" = "agent scratch; rip what you made";
        "/home/marshall/.cache/kache" = "Kache's Rust build cache (5 GiB limit, prunes itself)";
        "/nix/store" = "only through `nix-collect-garbage` as root, after asking Mars";
      };

      delegate = {
        "Most agent work, Android, desktops and the phone" = "argo (`ssh argo`; Tailscale name builder)";
        "Apple builds, iOS Simulator, iPad and macOS GUI work" = "canis (`ssh canis`)";
        "Windows-native builds and GUI runs" = "the win11 Incus VM here, or the laptop only when Mars agrees";
      };

      peers = {
        builder = "argo, Mars's main agent machine (Tailscale name builder)";
        desktop-1od2lvu = "Mars's Windows laptop and daily desktop (`ssh windows`)";
        canis = "Mars's MacBook Air (macOS)";
        pixel-10-pro-xl = "Mars's phone; argo holds its adb";
        navis = "the laptop's NixOS install; online only when booted";
      };

      notes = [
        "Fleet notes for this host: ~/Projects/agent-fleet/machines/polaris.md."
      ];
    };
  };
}
