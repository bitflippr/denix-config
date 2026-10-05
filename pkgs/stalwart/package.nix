{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchurl,
}:
# Upstream's prebuilt release, the same binary argo ran before moving to NixOS.
# nixpkgs is still on 0.15, and Stalwart's data can't move back a minor version.
stdenv.mkDerivation rec {
  pname = "stalwart";
  version = "0.16.24";

  src = fetchurl {
    url = "https://github.com/stalwartlabs/stalwart/releases/download/v${version}/stalwart-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-UTkmkdSrZ4ZOhK9SFSd9vUoGn/r5oM65SgdGLiJIeEM=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];

  installPhase = ''
    runHook preInstall
    install -Dm755 stalwart $out/bin/stalwart
    runHook postInstall
  '';

  meta = {
    description = "All-in-one mail and collaboration server";
    homepage = "https://stalw.art";
    license = lib.licenses.agpl3Only;
    mainProgram = "stalwart";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
