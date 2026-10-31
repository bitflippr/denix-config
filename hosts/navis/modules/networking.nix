{
  delib,
  lib,
  pkgs,
  ...
}: let
  # Cloudflare Tunnel's edge (region1 and region2.v2.argotunnel.com). Through
  # the exit node it only takes HTTP/2: the edge's 1280-byte QUIC handshake
  # packets don't fit Tailscale's 1280 MTU. Sending it out the local network,
  # ahead of Tailscale's exit-node rule (5270), lets T3's relay client use QUIC.
  tunnelEdge =
    map (net: "-4 rule %s to ${net} table main priority 5200") ["198.41.192.0/24" "198.41.200.0/24"]
    ++ map (net: "-6 rule %s to ${net} table main priority 5200") ["2606:4700:a0::/48" "2606:4700:a8::/48"];
  ipRules = action: suffix:
    lib.concatMapStrings (rule: ''
      ${pkgs.iproute2}/bin/ip ${builtins.replaceStrings ["%s"] [action] rule}${suffix}
    '')
    tunnelEdge;
  delRules = ipRules "del" " 2>/dev/null || true";
in
  delib.module {
    name = "navis";

    nixos.ifEnabled.systemd.services.cloudflare-tunnel-direct = {
      description = "Route Cloudflare Tunnel's edge around the Tailscale exit node";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      # A lookup in main with no route (offline) falls through to the next rule.
      script = delRules + ipRules "add" "";
      preStop = delRules;
    };
  }
