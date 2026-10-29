# Dashboard panels for the TRMNL clock on the home network. The clock downloads 1-bit
# panel images from here over the LAN (port 8737) and draws the time itself.
{
  config,
  delib,
  pkgs,
  ...
}: let
  settings = (pkgs.formats.toml {}).generate "trmnl-panels.toml" {
    listen = "0.0.0.0:8737";
    timezone = "America/New_York";
    state_dir = "/var/lib/trmnl-panels";
    rotate_minutes = 5;
    fetch_minutes = 15;
    calendar.ics_url_file = config.sops.secrets.trmnl_calendar_url.path;
    # Same rounded location as the desktop weather widgets
    weather = {
      latitude = 40.0;
      longitude = -74.2;
    };
    fleet.hosts = [
      {
        name = "argo";
        nodes = [
          {
            node = "builder";
            os = "NixOS";
            ssh = "argo";
            kind = "linux";
          }
        ];
      }
      {
        name = "Polaris";
        nodes = [
          {
            node = "polaris";
            os = "NixOS";
            kind = "local";
            disk = "/mnt";
          }
        ];
      }
      {
        name = "canis";
        nodes = [
          {
            node = "canis";
            os = "macOS";
            ssh = "canis";
            kind = "macos";
          }
        ];
      }
      {
        # One laptop, three installs; whichever is booted fills the tile
        name = "navis";
        nodes = [
          {
            node = "desktop-1od2lvu";
            os = "Windows";
            ssh = "windows";
            kind = "windows";
          }
          {
            node = "navis";
            os = "NixOS";
          }
          {
            node = "vela";
            os = "macOS";
            ssh = "vela";
            kind = "macos";
          }
        ];
      }
    ];
  };
in
  delib.module {
    name = "polaris";

    nixos.ifEnabled.sops.secrets.trmnl_calendar_url = {
      # The calendar's private iCal address
      sopsFile = ../../../../secrets/trmnl-panels.yaml;
      key = "calendar_url";
      owner = "marshall";
      restartUnits = ["trmnl-panels.service"];
    };

    nixos.ifEnabled.systemd.services.trmnl-panels = {
      description = "Dashboard panels for the TRMNL clock";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "tailscaled.service"];
      wants = ["network-online.target"];
      # Chromium's config and caches; HOME stays marshall's so SSH finds its config and keys
      environment = {
        XDG_CONFIG_HOME = "/var/lib/trmnl-panels/config";
        XDG_CACHE_HOME = "/var/lib/trmnl-panels/cache";
      };
      serviceConfig = {
        ExecStart = "${pkgs.local.trmnl-panels}/bin/trmnl-panels --config ${settings}";
        # Reads the fleet machines over SSH with marshall's fleet key
        User = "marshall";
        StateDirectory = "trmnl-panels";
        Restart = "on-failure";
        RestartSec = 10;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    };
  }
