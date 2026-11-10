{ config, inputs, lib, pkgs, ... }:
let
  bun = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.bun;
  source = pkgs.fetchzip {
    url = "https://github.com/bymoses/browserctl/archive/a0540ca0b228a4e12e5c939cfa79206bbd84f1ad.tar.gz";
    hash = "sha256-p/BFeSGJdzEDDcmVYzRj1ErAXw9VEZJFotLTOYVUOkI=";
  };
  browserctl = pkgs.stdenvNoCC.mkDerivation {
    pname = "browserctl";
    version = "0.1.0-a0540ca";
    src = source;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/browserctl" "$out/bin" "$out/lib/mozilla/native-messaging-hosts"
      cp -r cli native-host extension autoconfig "$out/share/browserctl/"
      makeWrapper ${lib.getExe bun} "$out/bin/browserctl" \
        --add-flags "$out/share/browserctl/cli/browserctl.ts"
      makeWrapper ${lib.getExe pkgs.nodejs} "$out/bin/browserctl-native-host" \
        --add-flags "$out/share/browserctl/native-host/host.mjs"
      cat > "$out/lib/mozilla/native-messaging-hosts/dev.zen_native_agent.json" <<EOF
      {"name":"dev.zen_native_agent","description":"Zen Native Agent","path":"$out/bin/browserctl-native-host","type":"stdio","allowed_extensions":["zen-native-agent@local"]}
      EOF
      runHook postInstall
    '';
    meta = {
      description = "Control Zen tabs through a local Native Messaging bridge";
      homepage = "https://github.com/bymoses/browserctl";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "browserctl";
    };
  };
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.override {
    inherit (config.programs.zen-browser) policies enablePrivateDesktopEntry;
  };
  loader = pkgs.writeText "zen-native-agent-autoload.cfg" (
    lib.replaceStrings
      [ "__EXTENSION_PATH_JSON__" ]
      [ (builtins.toJSON "${browserctl}/share/browserctl/extension") ]
      (builtins.readFile "${source}/autoconfig/zen-native-agent-autoload.cfg.template")
  );
in
{
  home.packages = [ browserctl ];
  programs.zen-browser = {
    nativeMessagingHosts = [ browserctl ];
    unwrappedPackage = zen.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        chmod u+w "$out/lib/${zen.libName}" "$out/lib/${zen.libName}/defaults/pref"
        install -Dm644 ${source}/autoconfig/zen-native-agent-autoload-prefs.js \
          "$out/lib/${zen.libName}/defaults/pref/zen-native-agent-autoload.js"
        install -m644 ${loader} "$out/lib/${zen.libName}/zen-native-agent-autoload.cfg"
      '';
    });
  };
}
