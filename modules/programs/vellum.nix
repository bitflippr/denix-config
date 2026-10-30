{
  delib,
  inputs,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "programs.vellum";

  options.programs.vellum = with delib; {
    enable = boolOption false;
  };

  home.ifEnabled = {myconfig, ...}: let
    inherit (pkgs.stdenv.hostPlatform) system;

    # Caelestia's flake still pins Quickshell, so reuse that revision (and its
    # build) until the caelestia-shell input is dropped.
    quickshellBase = inputs.caelestia-shell.inputs.quickshell.packages.${system}.default;
    quickshellUnwrapped = quickshellBase.unwrapped.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./quickshell-workspace-address.patch ./quickshell-close-child-fds.patch];
    });

    # The T3 thread feed is a WebSocket, which Quickshell does not bundle.
    quickshell = (quickshellBase.withModules [pkgs.qt6.qtwebsockets]).overrideAttrs (old: {
      installPhase =
        builtins.replaceStrings
        ["${quickshellBase.unwrapped}"]
        ["${quickshellUnwrapped}"]
        old.installPhase;
    });

    vellum = pkgs.writeShellScriptBin "vellum" ''
      exec ${quickshell}/bin/quickshell -p ${../../files/vellum} "$@"
    '';

    fuzzel = lib.getExe pkgs.fuzzel;

    # Stand-in pickers until vellum has its own, in the same spirit: summoned,
    # then gone.
    pickers = [
      (pkgs.writeShellScriptBin "vellum-launch" ''
        exec ${fuzzel} --launch-prefix="systemd-run --user --scope --quiet --collect --"
      '')

      (pkgs.writeShellScriptBin "vellum-clipboard" ''
        set -o pipefail
        ${lib.getExe pkgs.cliphist} list \
          | ${fuzzel} --dmenu --prompt "copy  " --width 60 \
          | ${lib.getExe pkgs.cliphist} decode \
          | ${pkgs.wl-clipboard}/bin/wl-copy
      '')

      (pkgs.writeShellScriptBin "vellum-emoji" ''
        exec ${lib.getExe pkgs.rofimoji} --selector fuzzel --action copy --skin-tone neutral
      '')

      (pkgs.writeShellScriptBin "vellum-keys" ''
        hyprctl binds -j | ${lib.getExe pkgs.jq} -r '
          .[] | objects | select(.description != "") |
          ([if .modmask % 2 >= 1 then "shift" else empty end,
            if (.modmask / 4 | floor) % 2 == 1 then "ctrl" else empty end,
            if (.modmask / 8 | floor) % 2 == 1 then "alt" else empty end,
            if (.modmask / 64 | floor) % 2 == 1 then "super" else empty end]
            + [.key | ascii_downcase] | join(" + ")) as $keys
          | "\($keys)\t\(.description | ascii_downcase)"' \
          | ${pkgs.util-linux}/bin/column -t -s "$(printf '\t')" \
          | ${fuzzel} --dmenu --prompt "keys  " --width 70 >/dev/null
      '')
    ];
  in {
    home.packages = [vellum] ++ pickers;

    programs.fuzzel = {
      enable = true;
      settings.main = {
        font = "Maple Mono NF:size=12";
        terminal = "ghostty -e";
        lines = 12;
        width = 40;
        horizontal-pad = 24;
        vertical-pad = 16;
        inner-pad = 8;
      };
      settings.border = {
        width = 2;
        radius = 16;
      };
    };
    catppuccin.fuzzel.accent = "lavender";

    systemd.user.services.vellum = {
      Unit = {
        Description = "vellum desktop shell";
        After = ["hyprland-session.target"];
        PartOf = ["hyprland-session.target"];
      };

      Service = {
        ExecStart = "${vellum}/bin/vellum";
        Restart = "on-failure";
        RestartSec = 1;
        # Weather, clipboard and T3 token commands run from QML.
        Environment = "PATH=${lib.makeBinPath (with pkgs; [bash coreutils curl jq wl-clipboard])}:/run/current-system/sw/bin:/etc/profiles/per-user/${myconfig.constants.username}/bin";
      };

      Install.WantedBy = ["hyprland-session.target"];
    };
  };
}
