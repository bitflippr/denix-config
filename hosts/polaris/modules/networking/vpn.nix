{
  config,
  delib,
  lib,
  pkgs,
  ...
}: let
  # Cloudflare Tunnel's edge (region1 and region2.v2.argotunnel.com). Mullvad
  # drops traffic to it, so exit-node clients reach it over the ISP route, as
  # Polaris's own tunnels do; otherwise cloudflared on a client, such as T3's
  # relay client on navis, never connects.
  tunnelEdge = let
    v4 = net: {
      ip = "ip -4";
      iptables = "iptables";
      src = "100.64.0.0/10";
      inherit net;
    };
    v6 = net: {
      ip = "ip -6";
      iptables = "ip6tables";
      src = "fd7a:115c:a1e0::/48";
      inherit net;
    };
  in
    map v4 ["198.41.192.0/24" "198.41.200.0/24"]
    ++ map v6 ["2606:4700:a0::/48" "2606:4700:a8::/48"];
  ip = cmd: "${pkgs.iproute2}/bin/${cmd}";
  iptables = cmd: "${pkgs.iptables}/bin/${cmd}";
  tunnelEdgeUp =
    lib.concatMapStrings (e: ''
      ${ip e.ip} rule add from ${e.src} to ${e.net} table main priority 9998 2>/dev/null || true
      ${iptables e.iptables} -t nat -C POSTROUTING -s ${e.src} -d ${e.net} -o eno1 -j MASQUERADE 2>/dev/null \
        || ${iptables e.iptables} -t nat -A POSTROUTING -s ${e.src} -d ${e.net} -o eno1 -j MASQUERADE
    '')
    tunnelEdge;
  tunnelEdgeDown =
    lib.concatMapStrings (e: ''
      ${ip e.ip} rule del from ${e.src} to ${e.net} table main priority 9998 2>/dev/null || true
      ${iptables e.iptables} -t nat -D POSTROUTING -s ${e.src} -d ${e.net} -o eno1 -j MASQUERADE 2>/dev/null || true
    '')
    tunnelEdge;
in
  delib.module {
    name = "polaris";

    nixos.ifEnabled = {
      sops.secrets.mullvad_private_key = {
        owner = "root";
        mode = "0400";
      };

      services.tailscale = {
        enable = true;
        # No subnet routes. tailscale set leaves prefs it isn't given alone, so
        # this has to say so to drop a route once advertised (10.100.0.53, now
        # only for Incus guests).
        extraSetFlags = ["--accept-dns=false" "--advertise-exit-node" "--advertise-routes="];
        openFirewall = true;
        useRoutingFeatures = "server";
      };

      # Traffic accepted by this proxy becomes Polaris-originated traffic, so
      # it follows the normal ISP route instead of the wg-mullvad policy route
      # used for packets forwarded from Tailscale clients.
      services.microsocks = {
        enable = true;
        ip = "100.92.239.38";
        port = 1080;
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [1080];

      # It binds the tailnet address, so it waits for it. It only wants
      # tailscaled: the bound socket outlasts a tailscaled restart.
      systemd.services.microsocks = {
        after = ["tailscale-online.target"];
        wants = ["tailscale-online.target"];
      };

      networking.wireguard.interfaces.wg-mullvad = {
        ips = [
          "10.65.182.233/32"
          "fc00:bbbb:bbbb:bb01::2:b6e8/128"
        ];
        privateKeyFile = config.sops.secrets.mullvad_private_key.path;
        table = "51820";

        peers = [
          {
            # Mullvad us-uyk-wg-202, Secaucus NJ.
            publicKey = "8Rh2Qc+vXTREhJb/RfCcpXS13U9xSqy4Pnw4+Wwt7iE=";
            allowedIPs = ["0.0.0.0/0" "::/0"];
            endpoint = "104.36.50.33:51820";
            persistentKeepalive = 25;
          }
        ];

        postSetup = ''
          ${pkgs.iproute2}/bin/ip rule add to 194.242.2.2/32 table 51820 priority 9999 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -6 rule add to 2a07:e340::2/128 table 51820 priority 9999 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip rule add from 100.64.0.0/10 table 51820 priority 10000 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -6 rule add from fd7a:115c:a1e0::/48 table 51820 priority 10000 2>/dev/null || true
          ${pkgs.iptables}/bin/iptables -t nat -C PREROUTING -i tailscale0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null \
            || ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i tailscale0 -p udp --dport 53 -j REDIRECT --to-ports 53
          ${pkgs.iptables}/bin/iptables -t nat -C PREROUTING -i tailscale0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null \
            || ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i tailscale0 -p tcp --dport 53 -j REDIRECT --to-ports 53
          ${pkgs.iptables}/bin/ip6tables -t nat -C PREROUTING -i tailscale0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null \
            || ${pkgs.iptables}/bin/ip6tables -t nat -A PREROUTING -i tailscale0 -p udp --dport 53 -j REDIRECT --to-ports 53
          ${pkgs.iptables}/bin/ip6tables -t nat -C PREROUTING -i tailscale0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null \
            || ${pkgs.iptables}/bin/ip6tables -t nat -A PREROUTING -i tailscale0 -p tcp --dport 53 -j REDIRECT --to-ports 53
          ${pkgs.iptables}/bin/iptables -t nat -C POSTROUTING -s 100.64.0.0/10 -o wg-mullvad -j MASQUERADE 2>/dev/null \
            || ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 100.64.0.0/10 -o wg-mullvad -j MASQUERADE
          ${pkgs.iptables}/bin/ip6tables -t nat -C POSTROUTING -s fd7a:115c:a1e0::/48 -o wg-mullvad -j MASQUERADE 2>/dev/null \
            || ${pkgs.iptables}/bin/ip6tables -t nat -A POSTROUTING -s fd7a:115c:a1e0::/48 -o wg-mullvad -j MASQUERADE
          ${tunnelEdgeUp}
        '';

        postShutdown = ''
          ${pkgs.iproute2}/bin/ip rule del to 194.242.2.2/32 table 51820 priority 9999 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -6 rule del to 2a07:e340::2/128 table 51820 priority 9999 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip rule del from 100.64.0.0/10 table 51820 priority 10000 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -6 rule del from fd7a:115c:a1e0::/48 table 51820 priority 10000 2>/dev/null || true
          ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i tailscale0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || true
          ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i tailscale0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || true
          ${pkgs.iptables}/bin/ip6tables -t nat -D PREROUTING -i tailscale0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || true
          ${pkgs.iptables}/bin/ip6tables -t nat -D PREROUTING -i tailscale0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || true
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 100.64.0.0/10 -o wg-mullvad -j MASQUERADE 2>/dev/null || true
          ${pkgs.iptables}/bin/ip6tables -t nat -D POSTROUTING -s fd7a:115c:a1e0::/48 -o wg-mullvad -j MASQUERADE 2>/dev/null || true
          ${tunnelEdgeDown}
        '';
      };
    };
  }
