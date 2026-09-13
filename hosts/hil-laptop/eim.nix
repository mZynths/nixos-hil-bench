{ lib, stdenvNoCC, fetchzip, autoPatchelfHook, zlib, gcc-unwrapped }:

# ESP-IDF Installation Manager (EIM) CLI.
# Upstream ships a dynamically-linked Rust binary (glibc, libz, libgcc_s) despite
# docs claiming a static build, so autoPatchelfHook rewrites its interpreter/rpath.
stdenvNoCC.mkDerivation rec {
  pname = "eim";
  version = "0.1.7";

  src = fetchzip {
    url = "https://github.com/espressif/idf-im-cli/releases/download/v${version}/eim-v${version}-linux-x64.zip";
    hash = "sha256-oF/GGC0fimkS8+cX7wRBaAq3qzX0uMkax4cnz3G44FE=";
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
