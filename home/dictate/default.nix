{ pkgs, ... }:
let
  needle = pkgs.callPackage ../../pkgs/needle { };

  dictate = pkgs.writeShellApplication {
    name = "dictate";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      needle
      pipewire
      wl-clipboard
      wtype
    ];
    runtimeEnv.WHISTLE_MODEL = "${needle}/share/needle/whistle.cact";
    text = builtins.readFile ./dictate.sh;
  };
in
{
  home.packages = [ dictate ];
}
