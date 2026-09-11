{ lib, stdenvNoCC, fetchurl }:

# TMOG (Task Manager OG) ships its "AppImage" as a fully static-pie ELF with
# zero dynamic library dependencies (verified: no PT_INTERP, no DT_NEEDED
# entries) — it isn't actually a squashfs-based AppImage, just a
# self-contained binary, so it runs directly with no patching/FHS wrapping.
#
# No versioned/checksummed upstream release exists (indie beta, rolling
# download link); this pins whatever tmog.org served at packaging time via
# sha256. If tmog.org updates the binary, this build fails on a hash
# mismatch — bump sha256 to whatever `nix build` reports as "got:".
stdenvNoCC.mkDerivation {
  pname = "tmog";
  version = "unpinned"; # upstream has no version in the URL or binary

  src = fetchurl {
    url = "https://tmog.org/downloads/TMOG-Task-Manager-Linux-x86_64.AppImage";
    sha256 = "0baf064697d67732800d6315644697ec153b8e506a5173304c85f330b2dbe6d2";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    install -m755 $src $out/bin/tmog
  '';

  meta = with lib; {
    description = "TMOG (Task Manager OG) — system monitor";
    homepage = "https://tmog.org/";
    platforms = [ "x86_64-linux" ];
  };
}
