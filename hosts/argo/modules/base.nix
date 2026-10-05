{
  config,
  delib,
  inputs,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "argo";

  options.argo = with delib; {
    enable = boolOption false;
  };

  nixos.ifEnabled = let
    username = config.myconfig.constants.username;
  in {
    sops = {
      defaultSopsFile = ../../../secrets/argo.yaml;
      # The host key carried over from builder, so fleet hosts keep trusting it.
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    time.timeZone = "America/New_York";

    nix = {
      nixPath = ["nixpkgs=${inputs.nixpkgs}"];
      registry.nixpkgs.flake = inputs.nixpkgs;

      settings = {
        # Builds and their temporary trees go to the stripe, not RAM or the mirror.
        build-dir = "/scratch/nix-build";
        # Polaris builds here as nix-builder; agents run as marshall and stay untrusted.
        trusted-users = lib.mkForce ["root" "nix-builder"];
      };
    };

    users = {
      groups.nix-builder = {};
      users.nix-builder = {
        isSystemUser = true;
        group = "nix-builder";
        home = "/var/lib/nix-builder";
        createHome = true;
        shell = pkgs.bashInteractive;
        # Remote builds only: these keys can't open a shell.
        openssh.authorizedKeys.keys = map (key: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${key}'') [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGOjnrn81sbj5Lw2vssH8t2pPNyVWkZFvS+BGFTeNNsw nix-builder@polaris"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJe8dn/plNp53zGSzHTZjjrQbo94WWMZf7508agyIwQQ agenix"
        ];
      };
    };

    # Agents' baseline toolset, present in every shell and service.
    environment = {
      systemPackages = with pkgs; [
        android-tools
        curl
        fd
        gdb
        gh
        git
        git-lfs
        htop
        jq
        lldb
        local.stalwart-cli
        mosh
        nodejs_24
        opencode
        p7zip
        python3
        ripgrep
        rsync
        sqlite
        strace
        tmux
        unzip
        uv
        wget
        zip
      ];

      # Temporary files land on the stripe.
      sessionVariables.TMPDIR = "/scratch/tmp";
    };

    # Prebuilt binaries and `#!/usr/bin/env` scripts work without packaging.
    services.envfs.enable = true;

    # Caches on the stripe too, for login shells and user services (T3 and the
    # harnesses it starts) alike.
    home-manager.users.${username} = {
      xdg.cacheHome = "/scratch/cache/${username}";
      systemd.user.sessionVariables.TMPDIR = "/scratch/tmp";
    };

    systemd.tmpfiles.rules = [
      "d /scratch/tmp 1777 root root 10d"
      "d /scratch/cache 0755 root root - -"
      "d /scratch/cache/${username} 0700 ${username} users - -"
      "d /scratch/nix-build 0755 root root - -"
    ];

    virtualisation.docker = {
      enable = true;
      daemon.settings.data-root = "/scratch/docker";
    };

    services.tailscale.enable = true;

    programs.mosh = {
      enable = true;
      openFirewall = false;
    };
  };
}
