{ lib, stdenvNoCC, fetchzip, buildFHSEnv
, curl, stdenv, xorg, fontconfig, freetype, dbus, wayland, libxkbcommon
, libGL, mesa, alsa-lib, glib, zlib, nss, cups
}:

# Binary Ninja Free ships as a plain zip (not a real AppImage) with a
# self-contained Qt6 distribution, and its binaries use standard
# /lib64/ld-linux-x86-64.so.2 interpreters and $ORIGIN-relative paths for
# their own bundled libs (plugins/libghidra.so, plugins/lldb/lib/*) — so an
# FHS sandbox is more robust here than hand-patching every ELF's rpath:
# missing system libs (libcurl, X11/xcb, fontconfig, GL, wayland, ...) just
# need to be present in the sandbox root, not individually rpath-patched.
#
# NOTE: not build-tested on an actual NixOS machine (no builder available
# in this environment). Run `nix build`/`nixos-rebuild build` and iterate on
# targetPkgs if binaryninja fails to start with a missing-library error.
let
  version = "6.0.10601";

  binaryninja-unwrapped = stdenvNoCC.mkDerivation {
    pname = "binaryninja-free-unwrapped";
    inherit version;

    src = fetchzip {
      url = "https://github.com/Vector35/binaryninja-api/releases/download/stable/${version}/binaryninja_free_linux.zip";
      sha256 = "3e8b9c5861abe6e9b04c86b5f9c4ad2dc86cedea79b72d7b0aee1fdcf7ce91d6";
      stripRoot = false;
    };

    dontBuild = true;

    installPhase = ''
      mkdir -p $out
      cp -r binaryninja $out/
      chmod +x $out/binaryninja/binaryninja $out/binaryninja/crashpad_handler
    '';
  };
in
buildFHSEnv {
  name = "binaryninja";

  targetPkgs = _: [
    binaryninja-unwrapped
    curl
    stdenv.cc.cc.lib # libstdc++, libgcc_s
    xorg.libX11
    xorg.libxcb
    xorg.libXext
    xorg.libXrender
    xorg.libXi
    xorg.libXrandr
    xorg.libXfixes
    xorg.libXcursor
    xorg.libSM
    xorg.libICE
    fontconfig
    freetype
    dbus
    wayland
    libxkbcommon
    libGL
    mesa
    alsa-lib
    glib
    zlib
    nss
    cups
  ];

  runScript = "${binaryninja-unwrapped}/binaryninja/binaryninja";

  meta = with lib; {
    description = "Binary Ninja Free — reverse engineering platform (FHS-wrapped upstream binary)";
    homepage = "https://binary.ninja/";
    platforms = [ "x86_64-linux" ];
  };
}
