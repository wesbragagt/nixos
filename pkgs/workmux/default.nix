{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
}:

let
  version = "0.1.279";
  assets = {
    x86_64-linux = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-linux-amd64.tar.gz";
      sha256 = "sha256-ckU6xozfA+4tdE6/+k1KlQeg7i3Zt1TNF42E9X11bmg=";
    };
    aarch64-linux = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-linux-arm64.tar.gz";
      sha256 = "sha256-xOaqU8CPIE+xLFAcKF3dxJyc4Vt7kDdtByJ86q/l4mc=";
    };
    x86_64-darwin = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-darwin-amd64.tar.gz";
      sha256 = "sha256-arEqk2gaBrNNsOtOOHKtSg3ao23TPv/2ASNGcG9Vv7I=";
    };
    aarch64-darwin = {
      url = "https://github.com/raine/workmux/releases/download/v${version}/workmux-darwin-arm64.tar.gz";
      sha256 = "sha256-/r0GkaZUtHSo4qJpbDXff24lNYJasiFK2t+utWhPRf0=";
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

  nativeBuildInputs = [ makeWrapper ];

  # gh honors CLICOLOR_FORCE over NO_COLOR and emits ANSI-colored --json output,
  # which workmux cannot parse. Some project dev shells export it.
  installPhase = ''
    mkdir -p $out/bin
    install -m755 workmux $out/bin/workmux
    wrapProgram $out/bin/workmux --unset CLICOLOR_FORCE
  '';

  meta.platforms = lib.attrNames assets;
}
