{
  lib,
  buildNpmPackage,
  fetchzip,
  runtimeShell,
  jq,
  bun-bin-1_4_2,
}:
buildNpmPackage (finalAttrs: {
  pname = "pi-coding-agent";
  version = "18.4.4";

  src = fetchzip {
    url = "https://registry.npmjs.org/@oh-my-pi/pi-coding-agent/-/pi-coding-agent-${finalAttrs.version}.tgz";
    hash = "sha256-4o0BZCrjUT9LEVnDIEL5itsTP5omyVWl52xo4Ytu+Ek=";
  };

  npmDepsHash = "sha256-vCi0dHBz+gUyNazV3B5zMBZqJ47SACjnQoa6HvZmsCg=";
  forceEmptyCache = true;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    # Remove devDependencies so npm does not try to fetch @types/bun in the
    # sandboxed build (no network access, only-if-cached mode).
    ${lib.getExe jq} 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  nativeBuildInputs = [ jq ];
  # onnxruntime-node's postinstall downloads from api.nuget.org, which the
  # sandbox blocks. The CLI runs prebuilt dist/cli.js, so scripts are not needed.
  npmFlags = [
    "--omit=dev"
    "--ignore-scripts"
  ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@oh-my-pi/pi-coding-agent
    cp -a . $out/lib/node_modules/@oh-my-pi/pi-coding-agent
    mkdir -p $out/bin
    cat > $out/bin/omp <<EOF
#!${runtimeShell}
exec "${lib.getExe bun-bin-1_4_2}" "$out/lib/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js" "\$@"
EOF
    chmod +x $out/bin/omp
    runHook postInstall
  '';

  meta = {
    description = "Oh My Pi coding agent CLI";
    homepage = "https://pi.dev";
    downloadPage = "https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent";
    license = lib.licenses.mit;
    mainProgram = "omp";
  };
})
