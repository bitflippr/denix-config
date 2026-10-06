{delib, ...}:
delib.host {
  name = "argo";

  system = "x86_64-linux";
  type = "server";

  myconfig = {
    argo.enable = true;

    system = {
      environment.enable = true;
      fleetApprovals.enable = true;
      nix.enable = true;
      programs.enable = true;
      security.enable = true;
      services.enable = true;
      stateversion.version = "26.11";

      users = {
        enable = true;
        extraGroups = ["docker" "kvm"];
        linger = true;
        shell = "bash";
      };
    };

    home = {
      fish.enable = true;
      nix-index.enable = true;
      packages.enable = true;
      shell.enable = true;
      t3code.enable = true;
    };

    programs = {
      bun.enable = true;
      codex-cli.enable = true;
    };
  };
}
