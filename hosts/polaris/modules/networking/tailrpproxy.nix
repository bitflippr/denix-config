{
  delib,
  pkgs,
  ...
}: let
  wireguardPort = 41642;
in
  delib.module {
    name = "polaris";

    # SideStore on the iPad (luna) installs apps by connecting to 10.7.0.1,
    # which LocalDevVPN would loop back into the device. tailrpproxy
    # advertises that address as a subnet route from its own tsnet node and
    # sends each connection back to the device that opened it, so SideStore
    # works with Tailscale as the only VPN on the device.
    #
    # It's a separate tailnet node ("tailrpproxy"), not Polaris's tailscaled:
    # native mode needs subnet SNAT off, which would change how Polaris's exit
    # node behaves. On first start it logs a login URL; once it has joined,
    # approve 10.7.0.1/32 for it in the Tailscale admin console and disable
    # its key expiry.
    nixos.ifEnabled = {
      systemd.services.tailrpproxy = {
        description = "tailrpproxy (SideStore loopback over the tailnet)";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];

        environment = {
          RPPROXY_TRANSPORT = "tsnet";
          RPPROXY_TSNET_HOSTNAME = "tailrpproxy";
          RPPROXY_TSNET_STATE_DIR = "/var/lib/tailrpproxy";
          RPPROXY_TSNET_PORT = toString wireguardPort;
          RPPROXY_HEALTH_LISTEN = "127.0.0.1:9090";
        };

        serviceConfig = {
          ExecStart = "${pkgs.local.tailrpproxy}/bin/tailrpproxy";
          DynamicUser = true;
          StateDirectory = "tailrpproxy";
          Restart = "always";
          RestartSec = 10;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
          CapabilityBoundingSet = "";
        };
      };

      # Direct WireGuard connections to the tsnet node, like tailscaled's own
      # port (services.tailscale.openFirewall).
      networking.firewall.allowedUDPPorts = [wireguardPort];
    };
  }
