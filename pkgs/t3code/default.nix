{
  cctools,
  copyDesktopItems,
  electron_43,
  fetchPnpmDeps,
  installShellFiles,
  lib,
  libicns,
  libsecret,
  makeBinaryWrapper,
  makeDesktopItem,
  node-gyp,
  nodejs,
  pkg-config,
  pnpm_11,
  pnpmBuildHook,
  pnpmConfigHook,
  python3,
  stdenv,
  t3codeSrc,
  writeDarwinBundle,
  xcbuild,
  cacert,
}:

stdenv.mkDerivation (finalAttrs: let
  appName = "T3 Code";
  electron = electron_43;
  pnpm = pnpm_11;
  desktopIcon =
    if stdenv.hostPlatform.isDarwin then
      "assets/prod/black-macos-1024.png"
    else
      "assets/prod/black-universal-1024.png";
in {
  pname = "t3code";
  version = "source";
  src = t3codeSrc;

  strictDeps = true;
  __structuredAttrs = true;

  postPatch = ''
    substituteInPlace apps/web/vite.config.ts \
      --replace-fail 'const host = explicitHost || "localhost";' \
                     'const host = explicitHost || "127.0.0.1";'
  '';

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
    node-gyp
    nodejs
    python3
    pnpmConfigHook
    pnpmBuildHook
    pnpm
    cacert
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    copyDesktopItems
    pkg-config
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
    libicns
    writeDarwinBundle
    xcbuild
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libsecret ];

  pnpmWorkspaces = [
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/desktop..."
    "@t3tools/scripts..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit pnpm;
    pname = "t3code-deps";
    version = "0.0.40";
    src = t3codeSrc;
    inherit (finalAttrs) pnpmWorkspaces;
    fetcherVersion = 4;
    hash = "sha256-+UsoURSM4VP+CgF1fWROBEB85EuH+iJJM/xDPFigCKk=";
  };

  preBuild = ''
    export pnpm_config_verify_deps_before_run=false
    node scripts/update-release-package-versions.ts ${finalAttrs.version}
    export npm_config_nodedir=${nodejs}
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'
  '';

  pnpmBuildScript = "build:desktop";

  postBuild = ''
    pnpm vp cache clean
  '';

  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    mkdir --parents "$out"/libexec/t3code/apps/{desktop,server}
    cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code
    cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code/apps/server
    cp --recursive --no-preserve=mode apps/desktop/{package.json,node_modules,dist-electron} "$out"/libexec/t3code/apps/desktop

    mkdir --parents "$out"/libexec/t3code/apps/desktop/prod-resources
    install --mode=444 ${desktopIcon} "$out"/libexec/t3code/apps/desktop/prod-resources/icon.png
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm755 native/browser-secret/build/${stdenv.hostPlatform.node.arch}/t3-browser-secret \
      "$out"/libexec/t3code/apps/desktop/prod-resources/browser-secret/t3-browser-secret
  '' + ''
    find "$out"/libexec/t3code -xtype l -delete

    makeWrapper ${lib.getExe nodejs} "$out"/bin/t3 \
      --add-flags "$out"/libexec/t3code/apps/server/dist/bin.mjs
    makeWrapper ${lib.getExe electron} "$out"/bin/t3code-desktop \
      --add-flags "$out"/libexec/t3code/apps/desktop \
      --inherit-argv0
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    find "$out"/libexec/t3code \
      -path '*/node-pty/prebuilds/darwin-*/spawn-helper' \
      -exec chmod 755 {} +

    mkdir --parents "$out/Applications/${appName}.app/Contents/"{MacOS,Resources}
    png2icns "$out/Applications/${appName}.app/Contents/Resources/t3code.icns" ${desktopIcon}
    ${stdenv.shell} ${lib.getExe writeDarwinBundle} "$out" "${appName}" t3code-desktop t3code
  '' + ''
    mkdir --parents "$out"/share/icons/hicolor/scalable/apps
    install --mode=444 ${desktopIcon} "$out"/share/icons/t3code.png
    install --mode=444 assets/prod/logo.svg "$out"/share/icons/hicolor/scalable/apps/t3code.svg

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "t3code";
      desktopName = appName;
      comment = "Local control surface for coding agents";
      exec = "t3code-desktop %U";
      terminal = false;
      icon = "t3code";
      startupWMClass = "t3code";
      categories = [ "Development" ];
    })
  ];

  meta = {
    description = "Local control surface for coding agents";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    mainProgram = "t3code-desktop";
    inherit (nodejs.meta) platforms;
  };
})
