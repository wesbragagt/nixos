{
  stdenv,
  lib,
  fetchurl,
}:

let
  version = "0.1.264";
  assets = {
    x86_64-linux = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-linux-amd64.tar.gz";
      sha256 = "";
    };
    aarch64-linux = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-linux-arm64.tar.gz";
      sha256 = "";
    };
    x86_64-darwin = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-darwin-amd64.tar.gz";
      sha256 = "";
    };
    aarch64-darwin = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-darwin-arm64.tar.gz";
      sha256 = "sha256-kYKsInMv+BmHBLgqwmq5KWW5QhTI+R/eyiHDb3HwDuk=";
    };
  };
  asset = assets.${stdenv.hostPlatform.system} or (throw "workmux: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "workmux";
  inherit version;

  src = fetchurl {
    inherit (asset) url sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    install -m755 workmux $out/bin/workmux
  '';

  meta.platforms = lib.attrNames assets;
}
