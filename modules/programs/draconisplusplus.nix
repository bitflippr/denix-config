{
  delib,
  inputs,
  ...
}:
delib.module {
  name = "programs.draconisplusplus";

  options.programs.draconisplusplus = with delib; {
    enable = boolOption false;
  };

  home.ifEnabled = {
    imports = [inputs.draconisplusplus.homeModules.default];

    programs.draconisplusplus = {
      enable = true;

      configFormat = "hpp";
      packageManagers = ["Cargo" "Nix"];
      username = "Mars";
      weatherUnit = "Imperial";

      location = {
        lat = 0.000000;
        lon = 0.000000;
      };
    };
  };
}
