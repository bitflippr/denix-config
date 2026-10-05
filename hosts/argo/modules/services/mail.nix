{
  delib,
  lib,
  pkgs,
  ...
}:
# Stalwart for skulldogged.dev, as installed on builder September 30, 2026.
# Nearly all of its configuration lives in its own database (changed through
# the web admin or stalwart-cli); this file only starts it and names the store.
delib.module {
  name = "argo";

  nixos.ifEnabled = {
    users = {
      groups.stalwart = {};
      users.stalwart = {
        isSystemUser = true;
        group = "stalwart";
        home = "/var/lib/stalwart";
      };
    };

    environment.etc."stalwart/config.json".text = builtins.toJSON {
      "@type" = "RocksDb";
      path = "/var/lib/stalwart/";
      blobSize = 16834;
      bufferSize = 134217728;
      poolWorkers = null;
      cacheSize = 134217728;
    };

    systemd.services.stalwart = {
      description = "Stalwart";
      wantedBy = ["multi-user.target"];
      # The public HTTPS listener and the resolver check need both in place.
      wants = ["network-online.target" "unbound.service"];
      after = ["network-online.target" "unbound.service"];
      conflicts = ["postfix.service"];

      # personal-agentd holds 8080 on the Tailscale address.
      environment.STALWART_RECOVERY_MODE_PORT = "18080";

      serviceConfig = {
        ExecStart = "${pkgs.local.stalwart}/bin/stalwart --config=/etc/stalwart/config.json";
        User = "stalwart";
        Group = "stalwart";
        AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
        StateDirectory = "stalwart";
        StateDirectoryMode = "0750";
        LogsDirectory = "stalwart";
        LimitNOFILE = 65536;
        KillMode = "process";
        KillSignal = "SIGINT";
        Restart = "on-failure";
        RestartSec = 5;
        SyslogIdentifier = "stalwart";
      };
    };

    # Stalwart's network-online ordering only works if something waits for it.
    systemd.network.wait-online.enable = lib.mkForce true;

    # A validating resolver of argo's own: DANE needs DNSSEC, and blocklists
    # such as Spamhaus refuse queries from shared resolvers. Only Stalwart uses it.
    services.unbound = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        server = {
          interface = ["127.0.0.1@5335" "::1@5335"];
          port = 5335;
          access-control = ["127.0.0.0/8 allow" "::1/128 allow"];
          do-ip6 = true;
          prefetch = true;
          qname-minimisation = true;
          hide-identity = true;
          hide-version = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      25 # SMTP
      443 # HTTPS (admin, webmail, autoconfig, ACME TLS-ALPN-01)
      465 # submissions
      993 # IMAPS
    ];
  };
}
