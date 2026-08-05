{ lib, pkgs, ... }:
{
  home.packages = [
    (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.bun else pkgs.callPackage ../../pkgs/bun-bin-1_3_14 { })
  ];

  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
  };

  home.sessionPath = [
    "$HOME/.bun/bin"
  ];

  home.activation.ensureBunGlobalDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.bun/bin"
  '';
}
