{ lib, stdenvNoCC, fetchurl, dpkg }:

stdenvNoCC.mkDerivation rec {
  pname = "vanta-agent";
  version = "2.21.0";

  src = fetchurl {
    url = "https://agent-downloads.vanta.com/targets/versions/${version}/vanta-amd64.deb";
    sha256 = "ffd83ef40351e701346e440e20be74f6850a2a6d4b7ed13c3a7069a46c8041d1";
  };

  nativeBuildInputs = [ dpkg ];
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/vanta" "$out/bin"
    cp -r var/vanta/. "$out/share/vanta/"
    ln -s ../share/vanta/vanta-cli "$out/bin/vanta-cli"
    runHook postInstall
  '';

  # The agent updates its own executables and verifies vendor binaries.
  dontFixup = true;

  meta = {
    description = "Vanta device compliance agent";
    homepage = "https://www.vanta.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "vanta-cli";
  };
}
