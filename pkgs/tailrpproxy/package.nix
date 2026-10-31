# Reflects SideStore's loopback address (10.7.0.1) back to the device over
# the tailnet, so SideStore installs and refreshes over Tailscale instead of
# LocalDevVPN. Version tags are the pinned tailscale.com release plus a patch
# revision; the ldflags match upstream's hack/version.sh.
{
  buildGo127Module,
  fetchFromGitHub,
  lib,
}:
buildGo127Module (final: {
  pname = "tailrpproxy";
  version = "1.104.2-rpp.1";

  src = fetchFromGitHub {
    owner = "eseiker";
    repo = "tailrpproxy";
    tag = "v${final.version}";
    hash = "sha256-23dt/E/4ib/48HpTEy7WijYdCV43GPyRduDhTFtwzJc=";
  };

  vendorHash = "sha256-jrv5ouDiAwsGG82ZFBpoICA3p1cuEw1f4ziZ50yFcog=";

  subPackages = ["cmd/tailrpproxy"];
  env.CGO_ENABLED = 0;
  ldflags = let
    tailscaleVersion = lib.head (lib.splitString "-" final.version);
  in [
    "-s"
    "-w"
    "-X tailscale.com/version.longStamp=${final.version}"
    "-X tailscale.com/version.shortStamp=${tailscaleVersion}"
  ];

  # Upstream's test suite isn't run on these hosts.
  doCheck = false;

  meta = {
    description = "Reflects SideStore RPPairing connections through a Tailscale tailnet";
    homepage = "https://github.com/eseiker/tailrpproxy";
    license = lib.licenses.unlicense;
    mainProgram = "tailrpproxy";
    platforms = lib.platforms.linux;
  };
})
