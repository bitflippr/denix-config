# waydroid-nvidia (github.com/Shiro836/waydroid-nvidia): Waydroid with NVIDIA GPU
# acceleration. Mirrors the release's AUR PKGBUILD (packaging/aur/waydroid-nvidia-bin),
# with its pinned hashes. Upstream's tools assume an FHS install under
# /usr/lib/waydroid-nvidia; system.waydroidNvidia links that path to this package and
# the few remaining FHS paths are patched below.
{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  makeWrapper,
  runtimeShell,
  waydroid,
  python3,
  zstd,
  binutils,
  e2fsprogs,
  getconf,
  kmod,
  lxc,
  nvidia-modprobe,
  util-linux,
}: let
  version = "0.2.0";
  tag = "v${version}";
  waydroidRev = "a33a5c0b31d89d6ce687381104b30aff4dd2d330";
  release = name: sha256:
    fetchurl {
      url = "https://github.com/Shiro836/waydroid-nvidia/releases/download/${tag}/${name}";
      inherit sha256;
    };

  srcTarball = fetchurl {
    url = "https://github.com/Shiro836/waydroid-nvidia/archive/refs/tags/${tag}.tar.gz";
    sha256 = "b643aa267e786c10d031a4d8bd89d37da7fc696bb2c43d633c37126a263b8545";
  };
  src = runCommand "waydroid-nvidia-src-${version}" {} ''
    mkdir $out
    tar -xzf ${srcTarball} -C $out --strip-components=1
  '';

  hostTar = release "waydroid-nvidia-host-x86_64-${tag}.tar.zst" "99d2814242e140d5ea91d3c23f4494500f3176e88746076ddae85a51d7d320b3";
  guestAndroidTar = release "waydroid-nvidia-guest-android-x86_64-${tag}.tar.zst" "7b57a74940bb1e5db1056a0154d2875f3b498eb6ab645665f6f6e90869f906b7";
  guestPrebuiltsTar = release "waydroid-nvidia-guest-prebuilts-${tag}.tar.zst" "7dd098c01e00159da66b3249872d48773bd3449aaae77eac23ab91fcabe3cedc";
  nativeTar = release "waydroid-nvidia-native-x86_64-${tag}.tar.zst" "33c9f75fa216c53828e93e8fb2a4e63562e3ab27b24c81268879ee48390fccf8";
  vendorZipName = "waydroid-nvidia-vendor-x86_64-${tag}.zip";
  vendorZip = release vendorZipName "692a0eeb45c288492f66ddba5b77ea15f00f88eca5354b048ec4b1e752aee29b";
  vendorChannelName = "waydroid-nvidia-vendor-ota-${tag}.json";
  vendorChannel = release vendorChannelName "2940a04d71ba26e32f85ec7223b19344a89cb9ecaafde4a715aaf9cff4ee3c60";

  # Waydroid at the release's pinned commit (1.6.3, as nixpkgs) with its two patches.
  # The setup checks that tools/helpers/nvidia_native.py is byte-identical to the
  # release's copy, so it must not be executable: nixpkgs' wrapPythonProgramsIn would
  # replace it with a shell wrapper.
  patchedWaydroid = waydroid.overrideAttrs (old: {
    version = "${old.version}-nvidia-${version}";
    src = fetchurl {
      url = "https://github.com/waydroid/waydroid/archive/${waydroidRev}.tar.gz";
      sha256 = "e7817beac7e26f7d54b2d9f49c847dab8e137c92e403825829e7abbd0b63c411";
    };
    patches =
      (old.patches or [])
      ++ [
        "${src}/patches/waydroid/0001-nvidia-integration.patch"
        "${src}/waydroid/0001-lxc-nvidia-native-mounts.patch"
      ];
    postPatch =
      (old.postPatch or "")
      + ''
        cmp ${src}/waydroid/nvidia_native.py tools/helpers/nvidia_native.py
        chmod -x tools/helpers/nvidia_native.py
      '';
  });

  # Everything the setup, the install-time gate and the container's ExecStartPre call.
  runtimeDeps = [
    patchedWaydroid
    python3
    binutils
    e2fsprogs
    getconf
    kmod
    lxc
    nvidia-modprobe
    util-linux
  ];

  guestLibs = [
    "vendor/lib/hw/vulkan.virtio.so"
    "vendor/lib/egl/libEGL_angle.so"
    "vendor/lib/egl/libGLESv1_CM_angle.so"
    "vendor/lib/egl/libGLESv2_angle.so"
    "vendor/lib64/hw/vulkan.virtio.so"
    "vendor/lib64/egl/libEGL_angle.so"
    "vendor/lib64/egl/libGLESv1_CM_angle.so"
    "vendor/lib64/egl/libGLESv2_angle.so"
    "vendor/lib64/libgbm_mesa_wrapper.so"
    "vendor/lib64/hw/hwcomposer.waydroid.so"
  ];
in
  stdenvNoCC.mkDerivation {
    pname = "waydroid-nvidia";
    inherit version src;

    nativeBuildInputs = [
      makeWrapper
      python3
      zstd
    ];

    # The release bundle is hash-checked against its BUILD-RECORD.json by every gate
    # run, and the guest ELFs are bionic: install them byte-identical.
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    postPatch = ''
      # The container unit drop-in the tools write: /etc/systemd/system is read-only
      # here. system.waydroidNvidia declares the same ExecStartPre and ordering in the
      # unit itself; this runtime copy only keeps the tools' own bookkeeping working.
      substituteInPlace dev/source-native \
        --replace-fail "Path('/etc/systemd/system/waydroid-container.service.d/source-native.conf')" \
                       "Path('/run/systemd/system/waydroid-container.service.d/source-native.conf')" \
        --replace-fail "PYTHON = '/usr/bin/python3'" "PYTHON = '${python3.interpreter}'" \
        --replace-fail "SYSTEM_WAYDROID = Path('/usr/lib/waydroid')" \
                       "SYSTEM_WAYDROID = Path('${patchedWaydroid}/lib/waydroid')" \
        --replace-fail "return [PYTHON, str(SYSTEM_WAYDROID / 'waydroid.py')]" \
                       "return ['${lib.getExe patchedWaydroid}']"

      # Impermanence bind-mounts /var/lib/waydroid and /var/lib/waydroid-nvidia
      # separately: same st_dev, but rename(2) between them fails with EXDEV. Take
      # upstream's own copy branch for the official vendor.img backup and restore.
      substituteInPlace packaging/native/vendor_image.py \
        --replace-fail "if os.stat(live).st_dev == os.stat(official).st_dev" "if False" \
        --replace-fail "if os.stat(official).st_dev == os.stat(images).st_dev" "if False"

      substituteInPlace packaging/native/wd-native \
        --replace-fail '#!/bin/bash' '#!${runtimeShell}' \
        --replace-fail 'PY=/usr/bin/python3' 'PY=${python3.interpreter}'

      # NixOS units carry no [Install] section; wantedBy already enables the container.
      substituteInPlace packaging/aur/waydroid-nvidia-bin/waydroid-nvidia-setup \
        --replace-fail '#!/bin/bash' '#!${runtimeShell}' \
        --replace-fail 'systemctl enable --now waydroid-container.service' 'systemctl start waydroid-container.service'
    '';

    installPhase = ''
      runHook preInstall

      lib=$out/lib/waydroid-nvidia
      mkdir -p host guest
      tar --zstd -xf ${hostTar} -C host
      tar --zstd -xf ${guestAndroidTar} -C guest
      tar --zstd -xf ${guestPrebuiltsTar} -C guest

      # Venus host renderer (venus mode only)
      install -Dm755 host/virgl_test_server host/virgl_render_server host/libvirglrenderer.so.1 -t $lib

      for rel in ${lib.escapeShellArgs guestLibs}; do
        install -Dm644 guest/$rel $lib/guest/$rel
      done
      install -Dm755 guest/system/bin/surfaceflinger $lib/guest/system/bin/surfaceflinger

      # The nvidia-prolapse bundle, vendor image and tools. install-native.sh checks the
      # zip's file name against its channel, so pass both under their release names.
      ln -s ${vendorZip} ${vendorZipName}
      ln -s ${vendorChannel} ${vendorChannelName}
      stage=$(mktemp -d)
      bash packaging/native/install-native.sh . ${nativeTar} ${vendorZipName} ${vendorChannelName} $stage ${tag}
      cp -r $stage/usr/lib/waydroid-nvidia/. $lib/

      a=packaging/aur/waydroid-nvidia-bin
      install -Dm644 $a/waydroid-nvidia.rules $out/lib/udev/rules.d/70-waydroid-nvidia.rules
      install -Dm644 $a/waydroid-nvidia-gpu.rules $out/lib/udev/rules.d/70-waydroid-nvidia-gpu.rules
      install -Dm755 $a/waydroid-nvidia-setup $out/libexec/waydroid-nvidia-setup
      makeWrapper $out/libexec/waydroid-nvidia-setup $out/bin/waydroid-nvidia-setup \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}

      runHook postInstall
    '';

    passthru = {
      waydroid = patchedWaydroid;
      inherit runtimeDeps;
    };

    meta = {
      description = "Waydroid with NVIDIA GPU acceleration";
      homepage = "https://github.com/Shiro836/waydroid-nvidia";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "waydroid-nvidia-setup";
    };
  }
