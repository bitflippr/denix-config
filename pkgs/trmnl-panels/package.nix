# Panel server for the TRMNL clock (firmware: ~/Projects/trmnl-clock on argo).
{
  lib,
  python3,
  playwright-driver,
  makeWrapper,
  runCommand,
  tailscale,
  openssh,
  coreutils,
  gawk,
  procps,
  bash,
}:
let
  python = python3.withPackages (
    p: with p; [
      aiohttp
      icalendar
      jinja2
      pillow
      playwright
      recurring-ical-events
    ]
  );
in
runCommand "trmnl-panels" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir -p $out/share/trmnl-panels $out/bin
  cp -r ${./trmnl_panels} $out/share/trmnl-panels/trmnl_panels
  cp -r ${./static} $out/share/trmnl-panels/static
  makeWrapper ${python}/bin/python $out/bin/trmnl-panels \
    --add-flags "-m trmnl_panels" \
    --prefix PYTHONPATH : $out/share/trmnl-panels \
    --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
    --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true \
    --prefix PATH : ${lib.makeBinPath [ tailscale openssh coreutils gawk procps bash ]}
''
