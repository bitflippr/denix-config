{
  config,
  delib,
  pkgs,
  ...
}: let
  # Consistent copies of live state; on the stripe, so the mirror isn't
  # filled with a second copy. Listed explicitly below, so restic includes it.
  backupStage = "/scratch/backup-stage";
  backupName = "argo";
  home = "/home/${config.myconfig.constants.username}";
in
  delib.module {
    name = "argo";

    # Polaris's pattern, in argo's own Backblaze bucket with a key scoped to
    # it, so nothing on argo can reach Polaris's backups.
    nixos.ifEnabled = {
      sops = {
        secrets = {
          restic_b2_key_id = {};
          restic_b2_application_key = {};
          restic_repository_password = {};
        };

        templates."restic-b2.env" = {
          owner = "root";
          group = "root";
          mode = "0400";
          content = ''
            AWS_ACCESS_KEY_ID=${config.sops.placeholder.restic_b2_key_id}
            AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.restic_b2_application_key}
            RESTIC_REPOSITORY=s3:s3.us-east-005.backblazeb2.com/argo-restic-125a85
          '';
        };
      };

      services.restic.backups.${backupName} = {
        initialize = true;
        environmentFile = config.sops.templates."restic-b2.env".path;
        passwordFile = config.sops.secrets.restic_repository_password.path;

        paths = [
          # Identities, credentials, configuration, checkouts with unpushed
          # work, the fleet's git origins, harness logins and history.
          "/etc"
          home
          "/root"
          "/var/lib/nixos"
          "/var/lib/nix-builder"
          backupStage
        ];

        # Matches the keep list agreed when builder became argo: unique work,
        # identities and history; nothing that can be rebuilt or re-downloaded.
        exclude = [
          "**/.#*"
          "**/.direnv"
          "**/node_modules"
          "**/target"

          # Toolchains, package caches and SDKs.
          "${home}/.cache"
          "${home}/.npm"
          "${home}/.bun"
          "${home}/.nvm"
          "${home}/.rustup"
          "${home}/.cargo"
          "${home}/.gradle"
          "${home}/.m2"
          "${home}/.vite-plus"
          "${home}/Android"
          "${home}/.local/share/claude"
          "${home}/.local/share/graveyard"

          # T3's runtimes, tools and release pipeline are rebuilt on demand;
          # its live databases are staged below instead.
          "${home}/.t3/runtime"
          "${home}/.t3/caches"
          "${home}/.t3/tools"
          "${home}/.t3/userdata/*.sqlite*"
          "${home}/.local/state/t3code-channel/source"
          "${home}/.local/state/t3code-channel/releases"

          # Upstream checkouts kept beside local patches.
          "${home}/Projects/android-helium-browser/chromium-*"
          "${home}/Projects/android-helium-browser/depot_tools"
          "${home}/Projects/android-helium-browser/helium"
        ];

        extraBackupArgs = [
          "--cleanup-cache"
          "--compression=auto"
          "--exclude-caches"
          "--one-file-system"
          "--tag=${backupName}"
          # Continues the history builder started before the move.
          "--host=${backupName}"
        ];

        pruneOpts = [
          "--group-by=host,tags"
          "--keep-daily=7"
          "--keep-weekly=5"
          "--keep-monthly=12"
          "--keep-yearly=3"
        ];

        checkOpts = ["--with-cache"];

        timerConfig = {
          OnCalendar = "*-*-* 03:15:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };

        backupPrepareCommand = ''
          #!${pkgs.runtimeShell}
          set -euo pipefail
          umask 0077

          stage=${backupStage}
          systemctl=${pkgs.systemd}/bin/systemctl
          rsync=${pkgs.rsync}/bin/rsync
          install=${pkgs.coreutils}/bin/install
          sqlite3=${pkgs.sqlite}/bin/sqlite3

          "$install" -d -m 0700 "$stage"

          sync_state() {
            local source=$1
            local destination=$2
            shift 2
            if [[ -d "$source" ]]; then
              "$install" -d -m 0700 "$destination"
              "$rsync" -aHAX --delete --delete-excluded --numeric-ids "$@" "$source/" "$destination/"
            fi
          }

          # Mail: stop Stalwart for the copy (a few seconds; senders retry).
          restart_stalwart=0
          if "$systemctl" is-active --quiet stalwart.service; then
            "$systemctl" stop stalwart.service
            restart_stalwart=1
          fi
          trap '[[ $restart_stalwart == 1 ]] && "$systemctl" start stalwart.service' EXIT
          sync_state /var/lib/stalwart "$stage/stalwart"
          if [[ $restart_stalwart == 1 ]]; then
            "$systemctl" start stalwart.service
            restart_stalwart=0
          fi
          trap - EXIT

          # T3's databases, copied consistently while it keeps running.
          "$install" -d -m 0700 "$stage/t3"
          for db in ${home}/.t3/userdata/*.sqlite; do
            [[ -f "$db" ]] || continue
            "$sqlite3" "$db" ".backup '$stage/t3/$(basename "$db")'"
          done

          # T3's launcher and active runtime (one version each), so T3 starts
          # straight after a restore instead of waiting on its release pipeline.
          launcher=$(${pkgs.gnugrep}/bin/grep -ohE '/runtime/versions/[^/"]+' ${home}/.config/systemd/user/t3code.service.d/*.conf | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.findutils}/bin/xargs ${pkgs.coreutils}/bin/basename)
          active=$(${pkgs.gnused}/bin/sed -nE 's/.*"activeVersion": *"([^"]+)".*/\1/p' ${home}/.t3/runtime/service-state.json)
          "$install" -d -m 0700 "$stage/t3-runtime"
          for version in $launcher $active; do
            sync_state "${home}/.t3/runtime/versions/$version" "$stage/t3-runtime/versions/$version"
          done
          "$install" -m 0600 ${home}/.t3/runtime/service-state.json ${home}/.t3/runtime/service-launcher.mjs "$stage/t3-runtime/"

          # State whose live copy is safe or atomically replaced.
          sync_state /var/lib/tailscale "$stage/tailscale"
          sync_state /scratch/docker/volumes "$stage/docker-volumes"
        '';
      };

      systemd = {
        services."restic-check-${backupName}-data" = {
          description = "Verify a rotating subset of the ${backupName} Restic repository";
          wants = ["network-online.target"];
          after = ["network-online.target"];
          environment.RESTIC_PASSWORD_FILE = config.sops.secrets.restic_repository_password.path;
          environment.RESTIC_CACHE_DIR = "/var/cache/restic-backups-${backupName}";
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.templates."restic-b2.env".path;
            ExecStart = "${pkgs.restic}/bin/restic check --with-cache --read-data-subset=5%";
            CacheDirectory = "restic-backups-${backupName}";
            CacheDirectoryMode = "0700";
          };
        };

        timers."restic-check-${backupName}-data" = {
          description = "Weekly Restic data-integrity verification";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "Sun *-*-* 05:00:00";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        tmpfiles.rules = ["d ${backupStage} 0700 root root - -"];
      };
    };
  }
