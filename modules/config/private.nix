{
  delib,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # Values this repo keeps out of public view. They're sops-encrypted in
  # secrets/eval.yaml and decrypted while the config is evaluated, because
  # some of them end up in build outputs (draconis++ compiles its plugin
  # config in). Decryption needs allow-unsafe-native-code-during-evaluation,
  # which `fleet switch` and the dev shell's `build` pass for these builds
  # only (along with --no-eval-cache, since the eval cache ignores that
  # setting), and the eval age key, which sops-nix installs from
  # secrets/eval-key.yaml and Home Manager copies to
  # ~/.config/sops/age/eval.txt, where sandboxed builds can read it too.
  # Without either, every value is null and the modules using them leave
  # those settings out, so the flake still evaluates for anyone.
  decrypt = builtins.toFile "decrypt-eval-secrets.sh" ''
    key="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/eval.txt}"
    sops=""
    for candidate in sops /run/current-system/sw/bin/sops "/etc/profiles/per-user/$USER/bin/sops" "$HOME/.nix-profile/bin/sops"; do
      if command -v "$candidate" >/dev/null 2>&1; then
        sops="$candidate"
        break
      fi
    done
    if [ -n "$sops" ] && [ -r "$key" ] && json="$(SOPS_AGE_KEY_FILE="$key" "$sops" -d --output-type json "$1" 2>/dev/null)"; then
      # builtins.exec parses its output as a Nix expression: print a string.
      printf '"%s"\n' "$(printf '%s' "$json" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g')"
    else
      echo null
    fi
  '';

  raw =
    if builtins ? exec
    then builtins.exec ["/bin/sh" decrypt "${../../secrets/eval.yaml}"]
    else null;

  values =
    if raw == null
    then {}
    else builtins.fromJSON raw;

  evalKey = {
    sopsFile = ../../secrets/eval-key.yaml;
    key = "sops_eval_age_key";
  };
in
  delib.module {
    name = "private";

    options.private = {
      weather = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            lat = lib.mkOption {type = lib.types.str;};
            lon = lib.mkOption {type = lib.types.str;};
          };
        });
        default = values.weather or null;
        readOnly = true;
        description = "Weather location as decimal-degree strings, or null when the eval secrets can't be decrypted.";
      };
    };

    nixos.always = {myconfig, ...}: {
      sops.secrets.sops_eval_age_key =
        evalKey
        // {
          owner = myconfig.constants.username;
          mode = "0400";
        };
    };

    home.always = {
      home.activation.sopsEvalKey = inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        src=/run/secrets/sops_eval_age_key
        dst="''${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/eval.txt"
        if [ -r "$src" ] && ! ${pkgs.diffutils}/bin/cmp -s "$src" "$dst" 2>/dev/null; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$dst")"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 "$src" "$dst"
        fi
      '';
    };
  }
