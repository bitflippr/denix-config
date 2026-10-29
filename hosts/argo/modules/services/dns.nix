{delib, ...}:
# The tailnet's backup resolver, behind Polaris. Tailscale clients ask both at
# once (admin console DNS: 100.92.239.38, then 100.100.69.116), so it blocks
# the same lists (modules/system/blocky.nix). argo isn't behind Mullvad, so it
# asks Mullvad over DoH instead of through the tunnel as Polaris does.
delib.module {
  name = "argo";

  nixos.ifEnabled = {
    services.blocky.settings = {
      # The tailnet only: argo's own lookups stay on resolved.
      ports.dns = [
        "100.100.69.116:53"
        "[fd7a:115c:a1e0::2c3b:4575]:53"
      ];
      upstreams.groups.default = ["https://dns.mullvad.net/dns-query"];
      # Reach Mullvad at its published addresses rather than asking Hetzner's
      # resolvers where it is.
      bootstrapDns = [
        {
          upstream = "https://dns.mullvad.net/dns-query";
          ips = ["194.242.2.2" "2a07:e340::2"];
        }
      ];
    };

    # It binds the tailnet addresses, so it waits for them.
    systemd.services.blocky = {
      after = ["tailscale-online.target"];
      wants = ["tailscale-online.target"];
    };
  };
}
