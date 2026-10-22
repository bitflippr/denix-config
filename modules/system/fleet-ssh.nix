{
  delib,
  lib,
  pkgs,
  ...
}:
# How other hosts' agents reach this one: OpenSSH on port 2223, over the
# tailnet only (Tailscale SSH holds port 22 on the tailnet address). The port
# used to go through Tailscale Serve, which ends each connection inside
# tailscaled, so every tailscaled restart cut every session. On the kernel's
# own path a restart only pauses them for the few seconds it takes.
delib.module {
  name = "system.fleetSsh";

  options.system.fleetSsh = with delib; {
    enable = boolOption false;
  };

  nixos.ifEnabled = {myconfig, ...}: let
    port = 2223;
  in {
    # Listen addresses rather than `ports`, which openFirewall would open
    # everywhere.
    services.openssh.listenAddresses = lib.concatMap (addr: [
      {
        inherit addr;
        port = 22;
      }
      {
        inherit addr port;
      }
    ]) ["0.0.0.0" "[::]"];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [port];

    # systemd 262's ssh_config drop-in is included from the Nix store. Inside
    # fleet's sandbox the store is owned by nobody, so ssh rejects the include
    # ("Bad owner or permissions") and every fleet command to another host
    # fails. Nothing here addresses machines or VMs through systemd-ssh-proxy.
    programs.ssh.systemd-ssh-proxy.enable = false;

    # Tailscale drops packets from these ranges on any other interface.
    programs.fleet.isolation.sshKeys = lib.mapAttrs (_: key: {
      inherit key;
      from = "100.64.0.0/10,fd7a:115c:a1e0::/48";
    }) (removeAttrs myconfig.sshKeys.agents [myconfig.host.name]);

    # A Serve mapping on the port would take its connections back into
    # tailscaled, and Serve mappings live on in Tailscale's state. While one
    # holds the port sshd can't bind it, so sshd restarts once it's gone
    # (its sessions carry on).
    systemd.services.fleet-ssh-unserve = {
      description = "Keep Tailscale Serve off fleet's SSH port";
      wantedBy = ["multi-user.target"];
      wants = ["tailscale-online.target"];
      after = ["tailscale-online.target"];
      path = [pkgs.tailscale pkgs.jq];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if tailscale serve status --json | jq -e '.TCP["${toString port}"]' >/dev/null; then
          tailscale serve --tcp=${toString port} off
          systemctl try-restart sshd.service
        fi
      '';
    };

    # Units that use the tailnet address wait for this. Bounded, so a
    # logged-out Tailscale fails it instead of holding up a switch.
    systemd.services.tailscale-wait-online.serviceConfig.TimeoutStartSec = "1min";
  };
}
