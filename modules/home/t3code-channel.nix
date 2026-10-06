{
  delib,
  pkgs,
  ...
}:
# argo's personal T3 Code release channel (see t3code-channel/README.md):
# every three hours it merges upstream main and the pinned pull-request
# overlays into skulldorged/t3code, builds a release and deploys it. It runs
# outside the agent sandbox, so it's installed from this repo into the Nix
# store, where agents can't change what it runs.
delib.module {
  name = "home.t3codeChannel";

  options.home.t3codeChannel = with delib; {
    enable = boolOption false;
  };

  home.ifEnabled = let
    channel = pkgs.runCommand "t3code-channel" {} ''
      mkdir -p $out
      cp ${./t3code-channel}/* $out/
    '';
  in {
    systemd.user.services.t3code-channel-update = {
      Unit = {
        Description = "Build and deploy the personal T3 Code release channel";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${channel}/update.sh";
        Environment = "PATH=%h/.nix-profile/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin";
        Nice = 10;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 6;
      };
    };

    systemd.user.timers.t3code-channel-update = {
      Unit.Description = "Check upstream T3 Code main and configured overlays every three hours";
      Timer = {
        OnCalendar = "*-*-* 01,04,07,10,13,16,19,22:20:00 UTC";
        Persistent = true;
        RandomizedDelaySec = "10m";
        Unit = "t3code-channel-update.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
