{
  pkgs,
  config,
  repoRoot,
  hostProfile ? { },
  ...
}:
{
  programs.quickshell = {
    enable = true;
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
  };

  home.packages = with pkgs; [
    networkmanager
    bluez
    wireplumber
    pavucontrol
  ];

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/quickshell/config";

  systemd.user.services.quickshell = {
    Unit.PartOf = [ "hyprland-session.target" ];
    Service = {
      Environment = [
        "QUICKSHELL_TRANSCRIBE=${if hostProfile.features.transcribe or false then "1" else "0"}"
        "LC_ALL=C.UTF-8"
      ];
      RestartSec = 1;
    };
  };
}
