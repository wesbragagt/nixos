{ pkgs, inputs, ... }:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  # Track unstable so the driver version matches the current npm playwright
  # release. A project pinned to another version needs its own browsers.
  browsers = unstable.playwright-driver.browsers;
in
{
  # Playwright downloads browsers that are not patched for NixOS, so
  # chrome-headless-shell fails on libglib-2.0.so.0. Point Playwright at the
  # Nix-built browsers instead.
  home.packages = [ browsers ];

  home.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };
}
