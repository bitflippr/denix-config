{
  delib,
  lib,
  pkgs,
  ...
}:
# Every fleet host's T3 approval endpoint. Each host with this enabled
# publishes its own on the tailnet (only /mcp; the rest of T3's HTTP surface
# keeps its existing routes), and its fleet broker accepts approvals from the
# others' threads, so an agent on any host can run `fleet elevate --host` or
# `fleet switch --on` against any other once Mars approves it in its thread.
delib.module {
  name = "system.fleetApprovals";

  options.system.fleetApprovals = with delib; {
    enable = boolOption false;
    # Keyed by hostname, which is what `fleet elevate` names its source by.
    endpoints = readOnly (attrsOfOption (submodule {
        options = {
          tailnetName = strOption null;
          port = portOption 8443;
        };
      }) {
        argo = {
          tailnetName = "builder";
          port = 8443;
        };
        polaris = {
          tailnetName = "polaris";
          # Incus already listens on 8443.
          port = 8444;
        };
        # canis isn't NixOS: fleetd's macos/install.sh sets up its broker, and
        # Tailscale Serve publishes its /mcp (8443 is taken there).
        canis = {
          tailnetName = "canis";
          port = 8444;
        };
      });
  };

  nixos.ifEnabled = {
    cfg,
    myconfig,
    ...
  }: let
    own = cfg.endpoints.${myconfig.host.name};
    url = e: "https://${e.tailnetName}.skate-altair.ts.net:${toString e.port}/mcp";
  in {
    programs.fleet.broker.t3Authorities =
      lib.mapAttrs (_: url) (removeAttrs cfg.endpoints [myconfig.host.name]);

    services.nginx = {
      enable = true;
      virtualHosts."fleet-approvals" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 3774;
          }
        ];
        locations."= /mcp" = {
          proxyPass = "http://127.0.0.1:3773/mcp";
          extraConfig = ''
            proxy_buffering off;
            proxy_read_timeout 120s;
          '';
        };
        locations."/".return = "404";
      };
    };

    systemd.services.fleet-approval-endpoint = {
      description = "Fleet approval authority over tailnet HTTPS";
      wantedBy = ["multi-user.target"];
      after = ["tailscaled.service" "nginx.service"];
      requires = ["tailscaled.service" "nginx.service"];
      # tailscaled starts before it has logged in, and `tailscale serve`
      # refuses until it has; at boot that left the endpoint down for good.
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=${toString own.port} http://127.0.0.1:3774";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=${toString own.port} off";
      };
    };
  };
}
