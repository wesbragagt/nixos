{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  openssl,
  alsa-lib,
  versionCheckHook,
}:
let
  platforms = {
    x86_64-linux = {
      npm = "linux-x64";
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-y8AKJtPQ4s7vxL6IkfioHvHjSbOxdbwK4wh2K8AB/ZM=";
    };
    aarch64-linux = {
      npm = "linux-arm64";
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-kEToQDl4ZPxsU50TcZsl+yars11TUzZsur97RVVAas0=";
    };
    x86_64-darwin = {
      npm = "darwin-x64";
      target = "x86_64-apple-darwin";
      hash = "sha256-WIqtKaR3m63IlNrrLkN1ftAdITNm/ZMf2aXsR/fjHhQ=";
    };
    aarch64-darwin = {
      npm = "darwin-arm64";
      target = "aarch64-apple-darwin";
      hash = "sha256-GB0u2ordvsoLaJyZbfIHKTlHkovdnIigl4N64cfmnKU=";
    };
  };
  platform = platforms.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.166.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${finalAttrs.version}-${platform.npm}.tgz";
    inherit (platform) hash;
  };

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    openssl
    alsa-lib
  ];
  dontBuild = true;

  # Keep the upstream layout so Codex can locate its code-mode and voice helpers.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/codex" "$out/bin"
    cp -r vendor/${platform.target}/. "$out/libexec/codex/"
    makeWrapper "$out/libexec/codex/bin/codex" "$out/bin/codex" \
      --prefix PATH : "$out/libexec/codex/codex-path"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "OpenAI coding agent CLI, pinned independently of nixpkgs";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames platforms;
  };
})
