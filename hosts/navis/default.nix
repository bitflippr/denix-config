{delib, ...}:
delib.host {
  name = "navis";

  rice = "catppuccin-mocha";
  system = "x86_64-linux";
  type = "desktop";

  myconfig = {
    navis.enable = true;

    system = {
      boot = {
        enable = true;
        enableIntelGraphics = true;
      };

      environment.enable = true;
      fleetApprovals.enable = true;
      fleetSsh.enable = true;
      fonts.enable = true;
      hardware.enable = true;
      i18n.enable = true;
      networking.enable = true;
      networking.hostName = "navis";
      nix.enable = true;
      programs.enable = true;
      security.enable = true;
      services.enable = true;
      users.enable = true;
      users.extraGroups = ["tss"];
      waydroidNvidia.enable = true;
    };

    home = {
      fish.enable = true;
      hyprland.enable = true;
      nix-index.enable = true;
      packages.enable = true;
      shell.enable = true;
      ghostty.enable = true;
    };

    programs = {
      bun.enable = true;
      cava.enable = true;
      codex-desktop.enable = true;
      cua-driver.enable = true;
      herdr.enable = true;
      draconisplusplus.enable = true;
      helium.enable = true;
      mpv = {
        enable = true;
        hardwareDecodeDevice = "/dev/dri/by-path/pci-0000:00:02.0-render";
      };
      mpd.enable = true;
      rmpc.enable = true;
      vellum.enable = true;

      git = {
        enable = true;
        credentialHelper = "libsecret";
        signingKey = "263409D620072FB8";
      };

      # "Rem Deadlock (New!!)", Wallpaper Engine Workshop item 3811045598, copied
      # off /mnt/Shared so a Windows-locked NTFS volume can't blank the desktop.
      video-wallpaper = {
        enable = true;
        video = "/home/marshall/.local/share/wallpapers/rem-deadlock.mp4";
      };
    };
  };
}
