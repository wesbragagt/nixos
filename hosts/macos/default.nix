{ ... }:
{
  system.primaryUser = "wesbragagt";
  users.users.wesbragagt.home = "/Users/wesbragagt";

  nixpkgs.config.allowUnfree = true;

  security.sudo.extraConfig = ''
    wesbragagt ALL=(ALL) NOPASSWD: ALL
  '';

  system.stateVersion = 6;
}
