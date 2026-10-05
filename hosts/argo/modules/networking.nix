{delib, ...}:
# Hetzner dedicated server in Finland, with the addressing assigned in
# Robot. Reverse DNS for both addresses is mail.skulldogged.dev.
delib.module {
  name = "argo";

  nixos.ifEnabled = {
    networking = {
      hostName = "argo";
      useDHCP = false;
      useNetworkd = true;

      nameservers = [
        "185.12.64.1"
        "185.12.64.2"
        "2a01:4ff:ff00::add:1"
        "2a01:4ff:ff00::add:2"
      ];

      firewall = {
        enable = true;
        # Fleet SSH, LocalSend and previews arrive over Tailscale.
        trustedInterfaces = ["tailscale0"];
        # Key-only SSH stays reachable publicly as a fallback if Tailscale is down.
        allowedTCPPorts = [22];
      };
    };

    systemd.network.networks."10-uplink" = {
      matchConfig.Name = "enp6s0";
      address = [
        "37.27.111.236/32"
        "2a01:4f9:3070:2256::2/64"
      ];
      routes = [
        {
          Gateway = "37.27.111.193";
          GatewayOnLink = true;
        }
        {Gateway = "fe80::1";}
      ];
      # Static IPv6 from Robot; Hetzner's routers shouldn't reconfigure it.
      networkConfig.IPv6AcceptRA = false;
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
