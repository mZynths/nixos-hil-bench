{ lib, stdenvNoCC, fetchzip, autoPatchelfHook, zlib, gcc-unwrapped }:

# ESP-IDF Installation Manager (EIM) CLI.
# Upstream ships a dynamically-linked Rust binary (glibc, libz, libgcc_s) despite
# docs claiming a static build, so autoPatchelfHook rewrites its interpreter/rpath.
stdenvNoCC.mkDerivation rec {
  pname = "eim";
  version = "0.1.7";

  src = fetchzip {
    url = "https://github.com/espressif/idf-im-cli/releases/download/v${version}/eim-v${version}-linux-x64.zip";
    sha256 = "c43fed481a1dc3bc32ac342c1b4099f4989f7b979f3228fb5b21972861380a3";
    stripRoot = false;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ zlib gcc-unwrapped.lib ];

  installPhase = ''
    mkdir -p $out/bin
    install -m755 $src/eim $out/bin/eim
  '';

  meta = with lib; {
    description = "ESP-IDF Installation Manager (EIM) CLI";
    homepage = "https://github.com/espressif/idf-im-cli";
    platforms = [ "x86_64-linux" ];
  };
}
