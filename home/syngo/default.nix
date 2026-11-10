{ config, inputs, pkgs, ... }:
let
  syngo = inputs.syngo.packages.${pkgs.stdenv.hostPlatform.system}.default;
  folder = "${config.home.homeDirectory}/p2p";
  setup = pkgs.writeShellScript "syngo-setup" ''
    set -eu
    ${syngo}/bin/syngo init
    ${syngo}/bin/syngo config set --listen 127.0.0.1:22001
    mkdir -p ${pkgs.lib.escapeShellArg folder}
    if ! ${syngo}/bin/syngo folder list --json | ${pkgs.jq}/bin/jq -e \
      --arg path ${pkgs.lib.escapeShellArg folder} \
      'any(.[]; .id == "p2p" and .path == $path)' >/dev/null; then
      ${syngo}/bin/syngo folder add ${pkgs.lib.escapeShellArg folder} --id p2p
    fi
  '';
in
{
  imports = [ inputs.syngo.homeManagerModules.default ];

  services.syngo = {
    enable = true;
    package = syngo;
    interface = "tailscale0";
  };

  systemd.user.services.syngo.Service.ExecStartPre = [ "${setup}" ];
}
