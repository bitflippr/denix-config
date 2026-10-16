{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "opencode";
  version = "2.0.30";

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
    hash = "sha512-oBw8dtg9BWiKkhyPOxA6GN+o78zmQfjgVi7Hz9de1pJZJVyGBMLlkYk1EwPeS+vWyOCSaty2FxCAsYH1bMdS2g==";
  };

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib zlib];

  # The executable contains Bun's embedded application data.
  dontStrip = true;
  doCheck = false;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode "$out/bin/opencode"
    runHook postInstall
  '';

  meta = {
    description = "OpenCode v2 coding agent";
    homepage = "https://opencode.ai/v2";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
