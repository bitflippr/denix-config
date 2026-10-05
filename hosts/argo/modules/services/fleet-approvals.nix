{delib, pkgs, ...}:
delib.module {
  name = "argo";

  nixos.ifEnabled = {
    # Only the authenticated MCP endpoint is reachable through this tailnet
    # listener. Keep the rest of T3's HTTP surface on its existing routes.
    services.nginx = {
      enable = true;
      virtualHosts."fleet-approvals" = {
        listen = [{addr = "127.0.0.1"; port = 3774;}];
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
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=8443 http://127.0.0.1:3774";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=8443 off";
      };
    };
  };
}
