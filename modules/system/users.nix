{
  delib,
  pkgs,
  config,
  lib,
  ...
}:
delib.module {
  name = "system.users";

  options.system.users = with delib; {
    enable = boolOption false;
    extraGroups = listOption [];
    linger = boolOption false;
    # Login shell. Agents on a host reached over SSH run bash one-liners, which fish rejects.
    shell = enumOption ["bash" "fish"] "fish";
  };

  nixos.ifEnabled = {myconfig, ...}: {
    users = {
      mutableUsers = myconfig.host.isServer;

      users.${myconfig.constants.username} =
        {
          isNormalUser = true;
          linger = myconfig.system.users.linger;
          shell = pkgs.${myconfig.system.users.shell};

          extraGroups =
            [
              "disk"
              "gamemode"
              "input"
              "networkmanager"
              "video"
              "wheel"
            ]
            ++ myconfig.system.users.extraGroups;
        }
        // lib.optionalAttrs myconfig.host.isDesktop {
          hashedPasswordFile = config.sops.secrets.passwd.path;
        };
    };
  };
}
