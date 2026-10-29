{delib, ...}:
# What `fleet where` tells agents about navis. Keep it to what an agent needs
# to work here without asking; the fleet notes hold the history.
delib.module {
  name = "navis";

  nixos.ifEnabled = {myconfig, ...}: {
    users.users.${myconfig.constants.username}.openssh.authorizedKeys.keys = myconfig.sshKeys.personal;

    programs.fleet = {
      enable = true;
      # Other hosts' agents arrive as system.fleetSsh sets up.
      isolation = {
        enable = true;
        # The sandbox hides key files but not agent sockets. The TPM agent
        # holds Mars's Polaris key, and `Host polaris` names it directly.
        hide = [
          "/run/user/1000/ssh-agent"
          "/run/user/1000/ssh-tpm-agent.sock"
          "/run/user/1000/keyring"
        ];
      };
      broker = {
        enable = true;
        users = ["marshall"];
      };

      host = {
        role = "Mars's laptop booted as NixOS (Hyprland desktop), and their daily machine while it's up. It's online only when the laptop is booted into navis, not Windows or vela. Most agent work runs on argo; work here when it needs this desktop, the laptop's hardware or files on it.";
        owner = "Mars (they/them)";

        conventions = [
          "Mars uses this desktop while it's up. Don't close their windows, stop their apps or change the desktop session unless the task is about it."
          "/ has about 20 GB free. Put builds, caches and job output in ~/scratch and rip them when done."
          "This is NixOS: get tools with `nix shell nixpkgs#<pkg>`. navis's config is denix-config hosts/navis, checked out at ~/nix-config, which often has Mars's uncommitted work: leave it alone and build on top of it. Make shared changes in argo's checkout and push."
          "To switch navis, pull ~/nix-config (`git -C ~/nix-config pull --ff-only`) and run `fleet switch --reason WHY` in it, or `fleet switch --on navis --reason WHY` from argo: either builds as you and asks Mars to activate the build. Never run nixos-rebuild over SSH."
          "Use `fleet job run` for anything that may outlive a tool call. Remove files with `rip`, not rm."
          "Agents run in fleet's sandbox. Plain ssh lands in fish, so wrap bash syntax in `bash -c`; `fleet on navis -- CMD` runs bash."
          "Work on other hosts through fleet rather than raw ssh: `fleet on HOST [--in PROJECT] -- CMD`, `fleet job run --on HOST -- CMD` for anything long, `fleet cp` and `fleet sync --to HOST` for files and checkouts."
        ];

        paths = {
          scratch = "/home/marshall/scratch";
          projects = "/home/marshall/Projects";
          config = "/home/marshall/nix-config";
        };

        mounts = {
          "/" = "btrfs on LUKS on the laptop's NVMe: system, Nix store, home; nearly full";
          "/mnt/Shared" = "partition shared with the laptop's Windows install (Steam library and more)";
          "/mnt/Music" = "Polaris's music share over SMB";
        };

        # `fleet job run` refuses new jobs below these.
        disk_floor = {
          "/" = "10G";
        };

        caches = {
          "/home/marshall/scratch" = "agent scratch; rip what you made";
          "/nix/store" = "only through `nix-collect-garbage` as root, after asking Mars";
        };

        delegate = {
          "Most agent work, Android, desktops and the phone" = "argo (`ssh argo`; Tailscale name builder)";
          "Apple builds, iOS Simulator, iPad and macOS GUI work" = "canis (`ssh canis`)";
          "Polaris's homelab services and its win11 VM" = "Polaris (`ssh polaris`)";
        };

        peers = {
          builder = "argo, Mars's main agent machine (Tailscale name builder)";
          polaris = "Mars's home server: the homelab and the win11 Incus VM";
          canis = "Mars's MacBook Air (macOS)";
          pixel-10-pro-xl = "Mars's phone; argo holds its adb";
          desktop-1od2lvu = "this same laptop booted as Windows; never online alongside navis";
          vela = "this same laptop booted as macOS; never online alongside navis";
        };

        # The laptop boots as one of these at a time.
        machines.laptop = ["desktop-1od2lvu" "navis" "vela"];

        notes = [
          "Fleet notes for this host: ~/Projects/agent-fleet/machines/navis.md on argo."
        ];
      };
    };
  };
}
