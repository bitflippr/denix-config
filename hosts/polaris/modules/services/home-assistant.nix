{
  config,
  delib,
  pkgs,
  ...
}:
delib.module {
  name = "polaris";

  nixos.ifEnabled = {
    sops.secrets.mqtt_gateway_password = {
      owner = "marshall";
      mode = "0400";
    };

    sops.secrets.google_assistant_service_account = {
      owner = "hass";
      group = "hass";
      mode = "0400";
      restartUnits = ["home-assistant.service"];
    };

    services.mosquitto = {
      enable = true;
      persistence = true;

      listeners = [
        {
          address = "192.168.1.82";
          port = 1883;
          users.sengled_gateway = {
            passwordFile = config.sops.secrets.mqtt_gateway_password.path;
            acl = [
              "readwrite sengled/#"
              "write homeassistant/#"
            ];
          };
        }
        {
          address = "127.0.0.1";
          port = 1883;
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
          acl = [
            "pattern readwrite sengled/#"
            "pattern read homeassistant/#"
          ];
        }
      ];
    };

    services.home-assistant = {
      enable = true;
      # aiohttp 3.14.5 is what 2026.10 pins upstream; nixpkgs still ships
      # 3.14.3, which has the October 19-20 DoS advisories. Drop once nixpkgs
      # catches up.
      package = pkgs.home-assistant.override {
        packageOverrides = _: super: {
          aiohttp = super.aiohttp.overridePythonAttrs (old: {
            version = "3.14.5";
            src = old.src.override {
              tag = "v3.14.5";
              hash = "sha256-gSxqab8AYJ6PsMP1PYWUxQ8TJ9KtEehoekLD8ziBt+g=";
            };
            # Cython 3.3.0 crashes on the `Final[...]` annotations in
            # aiohttp's WebSocket reader (aiohttp#13520); nixpkgs carries a
            # patch for 3.14.3 that doesn't fit 3.14.5, so build with
            # Cython 3.2 instead, as nixpkgs did before the patch.
            patches = [];
            build-system =
              map (d:
                if d.pname or "" == "cython"
                then super.cython_3_2
                else d)
              old.build-system;
            # 3.14.5's setup.cfg no longer has the coverage line nixpkgs edits.
            postPatch = ''
              rm -r vendor
              patchShebangs tools
              touch .git  # tools/gen.py uses .git to find the project root
              substituteInPlace Makefile \
                --replace-fail "cythonize: .install-cython" "cythonize:"
            '';
            doCheck = false;
          });
        };
      };
      };
      extraComponents = [
        "google_assistant"
        "mqtt"
      ];
      config = {
        "automation ui" = "!include automations.yaml";
        default_config = {};
        google_assistant = {
          project_id = "home-assistant-skulldogged";
          service_account = "!include ${config.sops.secrets.google_assistant_service_account.path}";
          report_state = true;
          expose_by_default = false;
          entity_config = {
            "light.sengled_local_gateway_sengled_bulb_1".expose = true;
            "light.sengled_local_gateway_sengled_bulb_2".expose = true;
          };
        };
        homeassistant = {
          external_url = "https://home.skulldogged.dev";
          internal_url = "http://192.168.1.82:8123";
        };
        http = {
          server_host = "0.0.0.0";
          server_port = 8123;
          use_x_forwarded_for = true;
          trusted_proxies = ["127.0.0.1"];
        };
      };
    };

    # The MQTT and Home Assistant sockets are admitted only from the LAN
    # source range in the host networking module.
  };
}
