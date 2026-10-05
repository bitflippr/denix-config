{
  delib,
  lib,
  ...
}:
# What `fleet where` tells agents about argo. Keep it to what an agent needs
# to work here without asking; the fleet notes hold the history.
delib.module {
  name = "argo";

  nixos.ifEnabled = {myconfig, ...}: {
    users.users.${myconfig.constants.username}.openssh.authorizedKeys.keys = myconfig.sshKeys.personal;

    programs.fleet = {
      enable = true;
      desktops.enable = true;
      containers.enable = true;
      isolation = {
        enable = true;
        # Stalwart's admin and root account passwords; agents use the API key.
        hide = ["/home/marshall/.config/stalwart"];
        # Other hosts' agents arrive through Tailscale Serve on port 2223.
        sshKeys = lib.mapAttrs (_: key: {
          inherit key;
          from = "127.0.0.1";
        }) (removeAttrs myconfig.sshKeys.agents ["argo"]);
      };
      secrets = {
        cloudflare = {
          file = "/home/marshall/.config/cloudflare/api-token";
          env = "CLOUDFLARE_API_TOKEN";
          description = "Cloudflare API token for the cf CLI and api.cloudflare.com";
        };
        stalwart = {
          file = "/home/marshall/.config/stalwart/api-key";
          env = "STALWART_TOKEN";
          description = "Stalwart admin API key; set STALWART_URL=https://mail.skulldogged.dev for stalwart-cli";
        };
      };
      broker = {
        enable = true;
        users = ["marshall"];
      };

      host = {
        role = "Mars's main agent-work machine (Hetzner, Finland). Most agent threads run here and hand work to other machines only when it has to happen there.";
        owner = "Mars (they/them)";

        conventions = [
          "Agents run as marshall in Mars's existing checkouts under ~/Projects; /builder/<name> are links to the same checkouts."
          "Build outputs, caches, temporary files, Docker data and VM images belong on /scratch. TMPDIR and XDG_CACHE_HOME already point there."
          "Use `fleet job run` for anything that may outlive a tool call: builds, dev servers, emulators, long downloads. `fleet job wait` returns within its budget, so don't sleep-poll."
          "This is NixOS: get tools with `nix shell nixpkgs#<pkg>` or `nix run`, never apt. System changes go in denix-config (hosts/argo), checked out at ~/Projects/denix-config."
          "Remove files with `rip`, not rm."
          "Stalwart serves mail for skulldogged.dev here. Don't stop or reconfigure it unless the task is about mail."
        ];

        paths = {
          scratch = "/scratch";
          projects = "/home/marshall/Projects";
          config = "/home/marshall/Projects/denix-config";
          fleet-notes = "/home/marshall/Projects/agent-fleet";
          # Agents' commits are signed with this key (registered on GitHub as
          # "argo agents"), so they're told apart from Mars's own.
          agent-signing-key = "/home/marshall/.ssh/id_ed25519_agent_signing";
          agent-allowed-signers = "/home/marshall/.ssh/allowed_signers_agents";
        };

        mounts = {
          "/" = "btrfs mirror (RAID1): system, Nix store, logs, mail; survives a drive failure";
          "/scratch" = "btrfs stripe shared with /home; a dead drive loses it, so home is backed up hourly";
        };

        delegate = {
          "Windows-native builds and GUI runs (WinUI, MSVC)" = "Polaris's win11 Incus VM";
          "Checks that need Mars's laptop hardware (RTX 3050, ASUS drivers)" = "the laptop (`ssh windows`), only when Mars agrees";
          "fastboot, recovery and other USB-only phone work" = "the laptop, where the phone's cable plugs in";
          "Apple builds, iOS Simulator, iPad and macOS GUI work" = "canis (`ssh canis`)";
          "Polaris's homelab services and config" = "Polaris (`ssh polaris`); its config is denix-config hosts/polaris";
          "GPU work beyond argo's small Radeon iGPU" = "Polaris or the laptop";
        };

        peers = {
          polaris = "NixOS home server: homelab services, GPU, Windows VM";
          desktop-1od2lvu = "Mars's Windows laptop and daily desktop (`ssh windows`)";
          canis = "Mars's MacBook Air (macOS)";
          pixel-10-pro-xl = "Mars's phone: adb over Tailscale, and T3 runs on it";
          navis = "the laptop's NixOS install; online only when booted";
        };

        # `fleet job run` refuses new jobs below these, so a runaway build can't
        # fill the mirror that holds the system and mail.
        disk_floor = {
          "/" = "15G";
          "/scratch" = "100G";
        };

        caches = {
          "/scratch/cache/marshall" = "per-tool caches (Nix eval, bun, opencode, mesa); rip any subfolder";
          "/scratch/cache/marshall/mbx" = "Rust build cache and managed target dirs: `mbx gc`";
          "/scratch/cargo-target" = "Cargo target dirs for services built here; rip a project's folder, it rebuilds";
          "/nix/store" = "only through `nix-collect-garbage` as root, after asking Mars";
        };

        devices.pixel = {
          serial = "57150DLCQ002Y1";
          model = "Pixel 10 Pro XL";
          tailscale = "pixel-10-pro-xl";
          cable_host = "the laptop (desktop-1od2lvu)";
          notes = "Mars's daily phone: stock Android 17 with KernelSU root. Reboot it or change its settings only when the task calls for it.";
        };

        notes = [
          "Fleet notes for this host: ~/Projects/agent-fleet/machines/argo.md."
        ];
      };
    };
  };
}
