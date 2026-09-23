{
  lib,
  hostSystem,
  hostProfile ? { },
  ...
}:
let
  isLinux = lib.hasSuffix "-linux" hostSystem;
  isHeadless = hostProfile.headless or false;
in
{
  imports = [
    ./packages
    ./npm
    ./bun
    ./shell
    ./git
    ./ssh
    ./yazi
    ./schedules
  ]
  ++ lib.optionals (isLinux && !isHeadless) [
    ./apps
  ];
}
