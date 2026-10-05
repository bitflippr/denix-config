{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchurl,
}:
stdenv.mkDerivation rec {
  pname = "stalwart-cli";
  version = "1.0.13";

  src = fetchurl {
    url = "https://github.com/stalwartlabs/cli/releases/download/v${version}/stalwart-cli-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-G4UJt2ft0aF2k+CStRjEFhDsS3JPTmLEYb0ozUDGafc=";
  };

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];

  installPhase = ''
    runHook preInstall
    install -Dm755 stalwart-cli $out/bin/stalwart-cli
    runHook postInstall
  '';

  meta = {
    description = "Command-line administration for Stalwart";
    homepage = "https://github.com/stalwartlabs/cli";
    license = lib.licenses.agpl3Only;
    mainProgram = "stalwart-cli";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
