{
  delib,
  inputs,
  ...
}: let
  overlay = _: prev: {
    local = {
      wrapper-v2 = prev.callPackage ../../pkgs/wrapper-v2/package.nix {};
      cobalt = prev.callPackage ../../pkgs/cobalt/package.nix {};
      jellyfin = prev.callPackage ../../pkgs/jellyfin/package.nix {
        inherit inputs;
        pkgs = prev;
      };
      jellyfin-animated-artwork = prev.callPackage ../../pkgs/jellyfin-animated-artwork/package.nix {};
      lidarr = prev.callPackage ../../pkgs/lidarr/package.nix {};
      lidarr-gamdl-bridge = prev.callPackage ../../pkgs/lidarr-gamdl-bridge/package.nix {};
      lidarr-plugin-slskd = prev.callPackage ../../pkgs/lidarr-plugin-slskd/package.nix {};
      ranni-wallpaper = prev.callPackage ../../pkgs/ranni-wallpaper/package.nix {};
      rip2 = prev.callPackage ../../pkgs/rip2/package.nix {};
      slskd = prev.callPackage ../../pkgs/slskd/package.nix {};
      stalwart = prev.callPackage ../../pkgs/stalwart/package.nix {};
      stalwart-cli = prev.callPackage ../../pkgs/stalwart-cli/package.nix {};
      visor-bootmanager = prev.callPackage ../../pkgs/visor-bootmanager/package.nix {};
    };
  };
in
  delib.module {
    name = "nixpkgs";

    nixos.always.nixpkgs = {
      config.allowUnfree = true;
      overlays = [overlay];
    };

    darwin.always.nixpkgs = {
      config.allowUnfree = true;
      overlays = [overlay];
    };
  }
