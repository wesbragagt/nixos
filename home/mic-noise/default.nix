{ pkgs, ... }:
let
  micNoise = pkgs.writeShellApplication {
    name = "mic-noise";
    runtimeInputs = [ pkgs.python3 pkgs.ffmpeg pkgs.pulseaudio ];
    text = ''exec python3 ${./mic-noise.py} "$@"'';
  };
in
{
  home.packages = [ micNoise ];
  systemd.user.services.mic-noise = {
    Unit = {
      Description = "Local microphone noise suppression";
      After = [ "pipewire-pulse.service" ];
      Requires = [ "pipewire-pulse.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${micNoise}/bin/mic-noise daemon";
      Restart = "no";
      UMask = "0077";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
