{
  config,
  delib,
  pkgs,
  ...
}: let
  # Root-only state put in place by hand: db-password (the t3relay role's
  # password) and tunnel-token (the Cloudflare Tunnel that publishes Postgres
  # to the relay's Hyperdrive, behind a Cloudflare Access service token).
  stateDir = "/var/lib/t3-relay";
  # 5432 is taken by a project database run from a fleet job.
  port = 5433;
  postgres = config.services.postgresql.package;
in
  # Database for the fork's self-hosted T3 Connect relay. Postgres listens on
  # localhost only; the relay reaches it through the tunnel.
  delib.module {
    name = "argo";

    nixos.ifEnabled = {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_17;
        settings.port = port;
        ensureDatabases = ["t3relay"];
        ensureUsers = [
          {
            name = "t3relay";
            ensureDBOwnership = true;
          }
        ];
        authentication = ''
          host t3relay t3relay 127.0.0.1/32 scram-sha-256
          host t3relay t3relay ::1/128 scram-sha-256
        '';
      };

      systemd.tmpfiles.rules = ["d ${stateDir} 0700 root root -"];

      # ensureUsers creates the role without a password.
      systemd.services.t3-relay-db-password = {
        description = "Set the t3relay Postgres role's password";
        wantedBy = ["multi-user.target"];
        requires = ["postgresql.service"];
        after = ["postgresql.service" "postgresql-setup.service"];
        unitConfig.ConditionPathExists = "${stateDir}/db-password";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          LoadCredential = "db-password:${stateDir}/db-password";
        };
        # Through the environment, so the password stays out of argv.
        script = ''
          T3RELAY_PASSWORD="$(< "$CREDENTIALS_DIRECTORY/db-password")" \
            ${postgres}/bin/psql -p ${toString port} -v ON_ERROR_STOP=1 -d postgres <<'SQL'
          \getenv password T3RELAY_PASSWORD
          ALTER ROLE t3relay PASSWORD :'password';
          SQL
        '';
      };

      systemd.services.t3-relay-db-tunnel = {
        description = "Cloudflare Tunnel for the T3 relay database";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target" "postgresql.service"];
        unitConfig.ConditionPathExists = "${stateDir}/tunnel-token";
        serviceConfig = {
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/tunnel-token";
          LoadCredential = "tunnel-token:${stateDir}/tunnel-token";
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = 5;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    };
  }
