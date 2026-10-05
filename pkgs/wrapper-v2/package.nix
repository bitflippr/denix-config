{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  androidenv,
  cmake,
  ninja,
  nlohmann_json,
}: let
  src = fetchFromGitHub {
    owner = "glomatico";
    repo = "wrapper-v2";
    rev = "100e0a864e883e03a3ac450a780dd9563fff5271";
    hash = "sha256-vJekQlmEnB8q/hQKbuoFiJsksKlr83ibHuNonQBfT4k=";
  };
  ndk =
    ((androidenv.override {licenseAccepted = true;}).composeAndroidPackages {
      includeNDK = true;
      ndkVersions = ["23.1.7779620"];
      platformVersions = [];
      buildToolsVersions = [];
      includeEmulator = false;
    }).ndk-bundle;
  supervisor = rustPlatform.buildRustPackage {
    pname = "wrapperd";
    version = "0.1.0";
    inherit src;
    cargoHash = "sha256-VT9yR6oEWWuUnofFamBocgMNR8mx9XB4gHM4OTTET7M=";
    doCheck = false;
    postPatch = ''
      substituteInPlace src/rust/main.rs --replace-fail '"/app/wrapper"' '"${launcher}/bin/wrapper"'
    '';
  };
  launcher = stdenv.mkDerivation {
    pname = "wrapper-v2-launcher";
    version = "0.1.0";
    inherit src;
    dontConfigure = true;
    doCheck = false;
    # Upstream reads /proc/self/status after the chroot, where /proc isn't
    # mounted until a worker has run, so the first worker skips its PID
    # namespace. Outside one, Polaris's 7-digit pids overflow the 16-bit
    # thread ids in old bionic's mutexes and the worker deadlocks.
    postPatch = ''
      substituteInPlace src/launcher/wrapper.c \
        --replace-fail '    if (ensure_dir(ROOTFS "/dev", 0755) != 0) return 1;' \
          '    int new_pid_ns = has_cap_sys_admin();
    if (ensure_dir(ROOTFS "/dev", 0755) != 0) return 1;' \
        --replace-fail '    if (has_cap_sys_admin()) {' '    if (new_pid_ns) {'
    '';
    buildPhase = ''
      $CC -Wall -Wextra -O2 src/launcher/wrapper.c -o wrapper
    '';
    installPhase = ''
      install -Dm755 wrapper "$out/bin/wrapper"
    '';
  };
  worker = stdenv.mkDerivation {
    pname = "wrapper-v2-worker";
    version = "0.1.0";
    inherit src;
    nativeBuildInputs = [cmake ninja];
    doCheck = false;
    dontUseCmakeConfigure = true;
    dontStrip = true;
    dontPatchELF = true;
    buildPhase = ''
      ndkRoot="${ndk}/libexec/android-sdk/ndk/23.1.7779620"
      cmake -S src/daemon -B build -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ndkRoot/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=x86_64 -DANDROID_PLATFORM=android-21 \
        -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
        -DFETCHCONTENT_SOURCE_DIR_NLOHMANN_JSON=${nlohmann_json.src} \
        -DJSON_BuildTests=OFF \
        -DLIBS_DIR="$ndkRoot/sources/cxx-stl/llvm-libc++/libs/x86_64"
      cmake --build build -j "$NIX_BUILD_CORES"
    '';
    installPhase = ''
      install -Dm755 build/main "$out/system/bin/main"
    '';
  };
in
  stdenv.mkDerivation {
    pname = "wrapper-v2";
    version = "0.1.0";
    dontUnpack = true;
    dontBuild = true;
    # The Android worker must retain its linker layout and /system/lib64 path.
    dontPatchELF = true;
    dontStrip = true;
    doCheck = false;
    installPhase = ''
      mkdir -p "$out/bin" "$out/system/bin"
      ln -s ${supervisor}/bin/wrapperd "$out/bin/wrapperd"
      cp ${worker}/system/bin/main "$out/system/bin/main"
    '';
    meta = {
      description = "Native wrapper-v2 supervisor and Android worker";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "wrapperd";
    };
  }
