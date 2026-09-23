{
  config,
  lib,
  pkgs,
  hostProfile ? { },
  ...
}:

let
  isHeadless = hostProfile.headless or false;
  rebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -euo pipefail

    action="''${1:-switch}"
    case "$action" in
      boot|build|dry-build|dry-activate|switch|test)
        if [[ $# -gt 0 ]]; then
          shift
        fi
        ;;
      *)
        action="switch"
        ;;
    esac

    host="$(hostname -s 2>/dev/null || hostname)"
    host="''${host%%.*}"

    if [[ -z "$host" ]]; then
      echo "Unable to determine current hostname for NixOS rebuild" >&2
      exit 1
    fi

    echo "Rebuilding host '$host' with action '$action'..." >&2
    sudo nixos-rebuild "$action" --impure --flake /home/wesbragagt/nixos-config#"$host" "$@"
  '';
in
{
  imports = [
    ./modules/host-profile.nix
    ./modules/keyboard.nix
    ./modules/tailscale.nix
    ./modules/containers.nix
    ./modules/sops.nix
    ./modules/responsiveness.nix
    ./modules/cron.nix
  ]
  ++ lib.optionals (!isHeadless) [
    ./modules/graphics.nix
    ./modules/audio.nix
    ./modules/fonts.nix
    ./modules/hyprland.nix
    ./modules/login.nix
    ./modules/onepassword.nix
  ];

  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.wesbragagt = {
    isNormalUser = true;
    description = "wesbragagt";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "audio"
      "podman"
      "docker"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOS29+SNkpKHCMcaonfqERiIr/xKPuxu4sVv5yyIG33 wesbragagt@mac"
    ];
  };

  programs.zsh.enable = true;

  nix.package = pkgs.nixVersions.stable;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      chromium = prev.chromium.override { enableWideVine = true; };
    })
  ];

  environment.etc."chromium/policies/managed/roam-media-capture.json".text = builtins.toJSON {
    AudioCaptureAllowedUrls = [ "https://ro.am/*" ];
    VideoCaptureAllowedUrls = [ "https://ro.am/*" ];
    ScreenCaptureAllowedByOrigins = [ "https://ro.am" ];
    ScreenCaptureWithoutGestureAllowedForOrigins = [ "https://ro.am" ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    cacert
    rebuild
  ];

  # Provide common shared libraries for foreign binaries and Python wheels that
  # dlopen C/C++ dependencies (for example Arrow/Parquet wheels requiring
  # libstdc++.so.6). The Home Manager Python wrapper exposes this path through
  # LD_LIBRARY_PATH because nix-ld itself only helps executable startup.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      zstd
      openssl
      libffi
    ];
  };

  # Make the system CA bundle discoverable for tools that don't honour
  # NixOS's NIX_SSL_CERT_FILE (e.g. DuckDB's `ui` extension fetching web
  # assets from ui.duckdb.org).
  environment.variables = {
    SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
  };

  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

}
