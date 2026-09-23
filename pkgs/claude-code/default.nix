{
  lib,
  stdenv,
  buildNpmPackage,
  fetchzip,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  autoPatchelfHook,
  glibc,
  bubblewrap,
  procps,
  socat,
  sox,
}:
buildNpmPackage (finalAttrs: {
  pname = "claude-code";
  version = "2.1.280";

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${finalAttrs.version}.tgz";
    hash = "sha256-VG8Qw8tcEv0PvdwyAdrR/SB4ELEc81/LCbi+NGAQAMo=";
  };

  npmDepsHash = "sha256-VNEhkeLlcF4VRVTFux9VvAslgJpbcLIyuDmovPGiGnE=";

  strictDeps = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    cat > package.json <<'EOF'
    {
      "name": "@anthropic-ai/claude-code",
      "version": "2.1.280",
      "bin": {
        "claude": "bin/claude.exe"
      },
      "scripts": {
        "postinstall": "node install.cjs",
        "prepare": "node -e \"if (!process.env.AUTHORIZED) { console.error('ERROR: Direct publishing is not allowed.\\nPlease see the release workflow documentation to publish this package.'); process.exit(1); }\""
      },
      "engines": {
        "node": ">=18.0.0"
      },
      "type": "module",
      "author": "Anthropic <support@anthropic.com>",
      "license": "SEE LICENSE IN README.md",
      "description": "Use Claude, Anthropic's AI assistant, right from your terminal. Claude can understand your codebase, edit files, run terminal commands, and handle entire workflows for you.",
      "homepage": "https://github.com/anthropics/claude-code",
      "bugs": {
        "url": "https://github.com/anthropics/claude-code/issues"
      },
      "dependencies": {},
      "optionalDependencies": {
        "@anthropic-ai/claude-code-linux-x64": "2.1.280"
      },
      "files": [
        "bin/claude.exe",
        "install.cjs",
        "cli-wrapper.cjs",
        "sdk-tools.d.ts"
      ]
    }
    EOF
  '';

  dontNpmBuild = true;

  env.AUTHORIZED = "1";

  postInstall = ''
    rm -f $out/bin/claude
    printf '%s\n' \
      '#!${stdenv.shell}' \
      "exec \"$out/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe\" \"\$@\"" \
      > $out/bin/claude
    chmod +x $out/bin/claude

    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --unset DEV \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            procps
            sox
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  preferLocalBuild = true;
  allowSubstitutes = false;

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
  };
})
