{ pkgs, inputs, ... }:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  chromium = unstable.chromium.override {
    enableWideVine = true;
    commandLineArgs = "--remote-debugging-port=9222";
  };
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
in
{
  home.packages = [
    chromium
    (pkgs.writeShellScriptBin "chromium-profile" ''
      export CHROMIUM_PROFILE_BROWSER=${chromium}/bin/chromium
      exec ${python}/bin/python ${./chromium-profile.py} "$@"
    '')
  ];
}
