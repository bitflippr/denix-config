{
  delib,
  inputs,
  ...
}: let
  # Security pins ahead of nixos-unstable (October 21, 2026). Remove each one
  # once the pinned nixpkgs carries the fixed version.
  #
  # Node.js October 21 security releases (Brotli decoder RCE, TLS hostname
  # bypasses): 24.22.1 is only in nixpkgs staging, 22.23.4 only on master.
  overlay = _: prev: let
    nodejsPin = node: version: hash:
      node.overrideAttrs (_: {
        inherit version;
        src = prev.fetchurl {
          url = "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
          inherit hash;
        };
      });
  in {
    local = rec {
      nodejs_24 = nodejsPin prev.nodejs_24 "24.22.1" "sha256-T1N5eWKAza6wwvNY/QS2oWzE+336g7WoyRqdljtDUjE=";
      nodejs_22 = nodejsPin prev.nodejs_22 "22.23.4" "sha256-e5rcgtYS0KKoY9lsRt4iklUuJQzuUZVuu+AUbEKqyuk=";

      # .NET 10.0.13 runtimes (Kestrel request smuggling) from nixpkgs PR
      # #574338; the SDK stays on the pinned nixpkgs, only the runtimes that
      # get wrapped into services change.
      dotnetCorePackages = let
        october =
          (import inputs.nixpkgs-dotnet {
            inherit (prev.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          }).dotnetCorePackages;
      in
        prev.dotnetCorePackages
        // {
          inherit (october) aspnetcore_10_0 runtime_10_0;
        };

      wrapper-v2 = prev.callPackage ../../pkgs/wrapper-v2/package.nix {};
      cobalt = prev.callPackage ../../pkgs/cobalt/package.nix {nodejs = nodejs_24;};
      jellyfin = prev.callPackage ../../pkgs/jellyfin/package.nix {
        inherit inputs;
        pkgs = prev // {inherit dotnetCorePackages;};
      };
      jellyfin-animated-artwork = prev.callPackage ../../pkgs/jellyfin-animated-artwork/package.nix {};
      lidarr = prev.callPackage ../../pkgs/lidarr/package.nix {};
      lidarr-gamdl-bridge = prev.callPackage ../../pkgs/lidarr-gamdl-bridge/package.nix {};
      lidarr-plugin-slskd = prev.callPackage ../../pkgs/lidarr-plugin-slskd/package.nix {};
      ranni-wallpaper = prev.callPackage ../../pkgs/ranni-wallpaper/package.nix {};
      rip2 = prev.callPackage ../../pkgs/rip2/package.nix {};
      slskd = prev.callPackage ../../pkgs/slskd/package.nix {inherit dotnetCorePackages;};
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
