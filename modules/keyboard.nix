{ config, lib, ... }:
let
  main = {
    capslock = "overload(control, esc)";
    esc = "esc";
  };
  swapKeyboards = config.wes.host.swapAltSuperKeyboards;
in
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = main;
    };
    # keyd prefers explicit IDs over "*", so only these keyboards get the swap.
    keyboards.swapAltSuper = lib.mkIf (swapKeyboards != [ ]) {
      ids = swapKeyboards;
      settings.main = main // {
        leftalt = "leftmeta";
        leftmeta = "leftalt";
      };
    };
  };
}
