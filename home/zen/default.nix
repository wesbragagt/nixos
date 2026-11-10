{ pkgs, inputs, ... }:
let
  bookmarks = import ./bookmarks.nix;
in
{
  programs.zen-browser = {
    enable = true;
    profiles.default = {
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        bitwarden
      ];
      bookmarks = bookmarks;
    };
  };

  xdg.configFile."zen/bookmarks.json".text = builtins.toJSON bookmarks.settings;
}
