{ pkgs, inputs, lib, ... }:
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
  webapps = pkgs.writeShellScriptBin "chromium-webapps" ''
    export WEBAPP_PROFILE=${profileLauncher}/bin/chromium-profile
    export WEBAPP_MANAGER="$0"
    exec ${python}/bin/python ${./webapps.py} "$@"
  '';
  profileLauncher = pkgs.writeShellScriptBin "chromium-profile" ''
    export CHROMIUM_PROFILE_BROWSER=${chromium}/bin/chromium
    exec ${python}/bin/python ${./chromium-profile.py} "$@"
  '';
in
{
  home.packages = [
    chromium
    webapps
    profileLauncher
  ];

  home.activation.chromiumWebApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${webapps}/bin/chromium-webapps sync
  '';

  xdg.dataFile."applications/chromium-focused.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Chromium (last focused profile)
    Exec=${pkgs.writeShellScript "chromium-open-focused" ''
      export HYPRCTL=${pkgs.hyprland}/bin/hyprctl
      export CHROMIUM=${chromium}/bin/chromium
      exec ${pkgs.python3}/bin/python ${./open-focused.py} "$@"
    ''} %U
    Icon=chromium
    Terminal=false
    MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/about;x-scheme-handler/unknown;
  '';
}
