{delib, ...}:
# The tailnet's resolvers: Polaris first, argo as the backup Tailscale races
# against it. Both block the same lists, so answers don't depend on which one
# wins. Hosts set their own listen addresses and upstreams.
delib.module {
  name = "system.blocky";

  options.system.blocky = with delib; {
    enable = boolOption false;
  };

  nixos.ifEnabled = {
    services.blocky = {
      enable = true;
      settings = {
        customDNS = {
          customTTL = "1h";
          mapping = {
            "voice.skulldogged.dev" = "192.168.1.82";
          };
        };
        # Tailnet names come from Tailscale's resolver; the upstreams don't know them.
        conditional.mapping."skate-altair.ts.net" = "100.100.100.100";
        blocking = {
          denylists = {
            ads = [
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
              "https://big.oisd.nl/"
              ''
                saawsedge.com
              ''
            ];
            tracking = [
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"
            ];
            # hagezi's threat intelligence feeds, which include URLhaus.
            malware = [
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif-onlydomains.txt"
            ];
          };
          clientGroupsBlock.default = ["ads" "tracking" "malware"];
        };
        caching = {
          minTime = "5m";
          maxTime = "30m";
          prefetching = true;
        };
      };
    };
  };
}
