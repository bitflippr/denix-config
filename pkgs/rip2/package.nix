# nixpkgs' rip2 at 0.9.7, which buries symlinks to directories on Linux too
# (0.9.6 pre-created a directory in their place and failed), plus a patch
# that buries sockets across filesystems by recreating the node. Drop the
# version bump once nixpkgs has 0.9.7.
{
  fetchFromGitHub,
  rip2,
  rustPlatform,
}:
rip2.overrideAttrs (final: old: {
  version = "0.9.7";
  src = fetchFromGitHub {
    owner = "MilesCranmer";
    repo = "rip2";
    tag = "v${final.version}";
    hash = "sha256-vs0t1Ye0M5GwJ0ayzRMutGKHtF806roMdRrW8O8AprQ=";
  };
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (final) pname src version;
    hash = "sha256-MrXwrxsczSJ2m0Em5/2NRXtkrWKBqXonvOY5L56o/xc=";
  };
  patches = (old.patches or []) ++ [./sockets.patch];
  # Upstream's test suite isn't run on these hosts.
  doCheck = false;
})
