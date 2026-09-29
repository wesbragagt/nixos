{ lib, pkgs, ... }:
let
  # The Python source is a real file, so it stays readable and lintable outside
  # the Nix build. flake8 runs as part of writePython3Bin.
  raw = pkgs.writers.writePython3Bin "schedules" {
    libraries = [ ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./schedules.py);

  # cron gives a job a minimal PATH, so the CLI carries its own tools.
  schedules = pkgs.symlinkJoin {
    name = "schedules";
    paths = [ raw ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/schedules \
        --prefix PATH : ${
          lib.makeBinPath (
            [
              pkgs.coreutils
              pkgs.tmux
            ]
            ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.cronie ]
          )
        }
    '';
  };
in
{
  home.packages = [ schedules ];
}
