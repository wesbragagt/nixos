{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  lib,
}:

let
  # Hugging Face revisions; "main" moves, so pin commits.
  needleRev = "d6c7d6a2e9655505e0f8e23339356dd1705900eb";
  whistleRev = "741118687e1f008f06d1351a402a731274789790";
in
stdenv.mkDerivation {
  pname = "needle";
  version = "3-${builtins.substring 0 7 needleRev}";

  src = fetchurl {
    url = "https://huggingface.co/Cactus-Compute/needle3/resolve/${needleRev}/linux-x86_64/needle";
    hash = "sha256-d8017nXFPfhTKzl+Ee18+UpF2JqfFPUIgf2caLpUotA=";
  };

  model = fetchurl {
    url = "https://huggingface.co/Cactus-Compute/whistle/resolve/${whistleRev}/whistle.cact";
    hash = "sha256-tuAvBIVorF0BogQlVsZYBh5pmsvAqioUOfUvPUYd/+s=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/needle"
    install -Dm644 "$model" "$out/share/needle/whistle.cact"
    runHook postInstall
  '';

  meta = {
    description = "Cactus Needle engine with the Whistle speech-to-text model";
    homepage = "https://github.com/cactus-compute/needle";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "needle";
  };
}
