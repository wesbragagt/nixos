{ ... }:
{
  system.primaryUser = "wesbragagt";
  users.users.wesbragagt.home = "/Users/wesbragagt";

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = 6;
}
