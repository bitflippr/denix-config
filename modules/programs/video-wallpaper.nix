{
  delib,
  pkgs,
  lib,
  ...
}:
delib.module {
  name = "programs.video-wallpaper";

  options.programs.video-wallpaper = with delib; {
    enable = boolOption false;

    video =
      description
      (readOnly (noDefault (strOption null)))
      "Path to the looping video drawn behind every window";
  };

  home.ifEnabled = {myconfig, ...}: let
    cfg = myconfig.programs.video-wallpaper;
    # Muted, looping, cropped to fill, decoded on the GPU's video engine.
    mpvOptions = "no-audio loop panscan=1.0 hwdec=auto really-quiet";
  in {
    systemd.user.services.video-wallpaper = {
      Unit = {
        Description = "Looping video wallpaper";
        After = ["hyprland-session.target"];
        PartOf = ["hyprland-session.target"];
        ConditionPathExists = cfg.video;
      };

      Service = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgs.mpvpaper)
          "--layer"
          "background"
          "-o"
          mpvOptions
          "*"
          cfg.video
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = ["hyprland-session.target"];
    };
  };
}
