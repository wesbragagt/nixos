{ lib, pkgs, inputs, hostProfile ? { }, ... }:
let
  enabled = (hostProfile.features or { }).dx-router or false;
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
  };
  runtime = unstable.llama-cpp.override { vulkanSupport = true; };
  model = pkgs.fetchurl {
    url = "https://huggingface.co/evalengine/decision-0.8b-gguf/resolve/ce993792ad283053004bf0230b1709ff7351bb24/decision-0.8b-Q8_0.gguf";
    sha256 = "efa1614fe5c7d84acb6b8acdf9fd0dda4a26acf110302732baa573d3332a4fef";
  };
in
{
  config = lib.mkIf (enabled && pkgs.stdenv.isLinux) {
    systemd.user.services.dx-router = {
      Unit = {
        Description = "Decision-0.8B local task router";
        After = [ "graphical-session-pre.target" ];
      };
      Service = {
        ExecStart = "${runtime}/bin/llama-server -m ${model} -c 2048 -ngl 99 -np 1 --host 127.0.0.1 --port 18085";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
