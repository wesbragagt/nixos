{ stdenvNoCC, fetchzip, lib }:

let
  platform =
    if stdenvNoCC.hostPlatform.isDarwin && stdenvNoCC.hostPlatform.isAarch64 then
      {
        name = "darwin-aarch64";
        hash = "sha256-87/El3jqhuolGOs2Mwcm2hKpgOAEI+jLs2taVYSw3nk=";
        binPath = "bun-darwin-aarch64/bun";
      }
    else if stdenvNoCC.hostPlatform.isDarwin then
      {
        name = "darwin-x64";
        hash = "sha256-FIXME=";
        binPath = "bun-darwin-x64/bun";
      }
    else
      {
        name = "linux-x64";
        hash = "sha256-QfuQ53tZoWw2EbNX38GmIn8Rqkn4h5LVD6JmNtPnib8=";
        binPath = "bun-linux-x64/bun";
      };
in
stdenvNoCC.mkDerivation rec {
  pname = "bun-bin";
  version = "1.4.4";

  src = fetchzip {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-${platform.name}.zip";
    hash = platform.hash;
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src/${platform.binPath}" "$out/bin/bun"

    runHook postInstall
  '';

  meta = {
    description = "Fast JavaScript runtime, package manager, bundler and test runner";
    homepage = "https://bun.sh";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" ];
    mainProgram = "bun";
  };
}
