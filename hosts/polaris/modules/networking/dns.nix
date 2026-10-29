{
  delib,
  pkgs,
  ...
}:
delib.module {
  name = "polaris";

  nixos.ifEnabled = {
    services = {
      resolved.enable = false;

      # The shared lists live in modules/system/blocky.nix. Mullvad's resolvers
      # only answer plain DNS inside its tunnel; vpn.nix routes them there.
      blocky.settings = {
        ports.dns = 53;
        upstreams.groups.default = [
          "194.242.2.2"
          "2a07:e340::2"
        ];
      };
    };

    systemd.services = {
      # Blocky's address for the Incus guests (incus.nix).
      polaris-blocky-service-ip = {
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.iproute2}/bin/ip address add 10.100.0.53/32 dev lo 2>/dev/null || true
        '';
        postStop = ''
          ${pkgs.iproute2}/bin/ip address del 10.100.0.53/32 dev lo 2>/dev/null || true
        '';
      };

      polaris-local-resolvconf = {
        wantedBy = ["multi-user.target"];
        after = ["blocky.service" "tailscaled-set.service"];
        requires = ["blocky.service"];
        serviceConfig.Type = "oneshot";
        script = ''
          printf 'nameserver 127.0.0.1\nnameserver ::1\n' > /etc/resolv.conf
        '';
      };
    };
  };
}
