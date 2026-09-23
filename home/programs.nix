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
    ./playwright
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
