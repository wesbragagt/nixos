{
  lib,
  buildNpmPackage,
  fetchzip,
  runtimeShell,
}:
buildNpmPackage (finalAttrs: {
  pname = "pi-coding-agent";
  version = "0.73.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${finalAttrs.version}.tgz";
    hash = "sha256-ZBSiOoKig+TGR7tswMro9CCmrQ5AI6Yf21XkBFastao=";
  };

  npmDepsHash = "sha256-bSGBcq8xx1CiXruIetVDpdz7D8qEiyd4oyRQSZXxe88=";
  forceEmptyCache = true;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    cat > $out/bin/pi <<EOF
#!${runtimeShell}
exec "$out/lib/node_modules/@mariozechner/pi-coding-agent/dist/cli.js" "$@"
EOF
    chmod +x $out/bin/pi
  '';


  meta = {
    description = "Minimal terminal coding harness";
    homepage = "https://pi.dev";
    downloadPage = "https://www.npmjs.com/package/@mariozechner/pi-coding-agent";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
})
