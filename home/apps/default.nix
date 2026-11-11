{
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  rofiColorsDir = "${repoRoot}/rofi/colors";
  rofiLaunchersDir = "${repoRoot}/rofi/launchers";
  footConfig = "${repoRoot}/home/apps/foot.ini";
  workmuxConfig = "${repoRoot}/home/apps/workmux.yaml";
in
{
  programs.foot.enable = true;
  programs.kitty = {
    enable = true;
    extraConfig = builtins.readFile ./kitty.conf;
  };

  programs.obsidian = {
    enable = true;
    vaults."notes-live-sync" = {
      target = "notes-live-sync";
    };
  };

  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "${pkgs.foot}/bin/foot";
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      drun-display-format = "{name}";
    };
    theme = "${config.xdg.configHome}/rofi/launchers/type-2/style-1.rasi";
  };

  home.file.".cache/nwg-dock-pinned".text = ''
    foot
    zen-beta
    thunar
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
      "image/jpeg" = "imv.desktop";
      "image/png" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/bmp" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/x-flv" = "mpv.desktop";
    };
  };

  xdg.dataFile."applications/rofi-bookmarks.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Bookmarks
    Comment=Open a bookmark from bookmarks.md in the default browser
    Exec=rofi-bookmarks
    Icon=bookmarks-organize
    Terminal=false
    Categories=Utility;
  '';

  xdg.dataFile."applications/calculator.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Calculator
    Comment=Type expressions in rofi and get results
    Exec=env ROFI_PLUGIN_PATH=${pkgs.rofi-calc}/lib/rofi rofi -show calc -modi calc -display-calc Calculator -window-title Calculator -p Calculator -no-show-match -no-sort
    Icon=accessories-calculator
    Terminal=false
    Categories=Utility;Calculator;
    Keywords=calc;calculator;math;
  '';

  xdg.configFile = {
    "foot/foot.ini".source = config.lib.file.mkOutOfStoreSymlink footConfig;
    "rofi/colors".source = config.lib.file.mkOutOfStoreSymlink rofiColorsDir;
    "rofi/launchers".source = config.lib.file.mkOutOfStoreSymlink rofiLaunchersDir;
    "workmux/config.yaml".source = config.lib.file.mkOutOfStoreSymlink workmuxConfig;
    "swappy/config".text = ''
      [Default]
      early_exit=true
      auto_save=true
      save_dir=$HOME/Screenshots
    '';
    "waypaper/config.ini".text = ''
      [Settings]
      language = en
      folder = /home/wesbragagt/Wallpapers
      monitors = All
      backend = swww
      fill = fill
      sort = name
      color = #ffffff
      subfolders = False
      show_hidden = False
      show_gifs_only = False
      number_of_columns = 3
      swww_transition_type = any
      swww_transition_step = 90
      swww_transition_angle = 0
      swww_transition_duration = 2
      swww_transition_fps = 60
      use_xdg_state = False
    '';
  };
}
