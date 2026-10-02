{ pkgs, ... }:
let
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    sha256 = "00nhqqvgwyl9zgyy7vk9i3n017q2wlncp5p7ymsk0cpkdp47jdx0";
  };

  transcribe = pkgs.writeShellApplication {
    name = "transcribe";
    runtimeInputs = with pkgs; [
      coreutils
      ffmpeg
      jq
      libnotify
      pipewire
      procps
      whisper-cpp
    ];
    runtimeEnv.WHISPER_MODEL = "${model}";
    text = builtins.readFile ./transcribe.sh;
  };
in
{
  home.packages = [ transcribe ];

  systemd.user.services.transcribe = {
    Unit = {
      Description = "Auto-record and transcribe meetings";
      After = [ "pipewire.service" ];
    };
    Service = {
      ExecStart = "${transcribe}/bin/transcribe daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
