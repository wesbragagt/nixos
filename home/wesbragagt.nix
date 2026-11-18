{
  lib,
  pkgs,
  inputs,
  hostSystem,
  hostProfile ? { },
  ...
}:
let
  isLinux = lib.hasSuffix "-linux" hostSystem;
  isDarwin = lib.hasSuffix "-darwin" hostSystem;
  # Hyprland/GTK desktop bits only apply to a Linux host with a display.
  isHeadless = (hostProfile.headless or false) || !isLinux;
  homeDirectory = if isDarwin then "/Users/wesbragagt" else "/home/wesbragagt";
  features = hostProfile.features or { };
  claudeCodeEnabled = features.claude-code or false;
  ompEnabled = features.omp or false;
  transcribeEnabled = features.transcribe or false;
  dictateEnabled = features.dictate or false;
  syngoEnabled = features.syngo or false;
  base = {
    imports = [
      ./repo-root.nix
      ./ccflare
      ./claude
      ./codex
      ./agents/writers/module.nix
      ./dx-router
      ./omp
      ./programs.nix
      ./tmux
      ./neovim
      ./sops
      inputs.sops-nix.homeManagerModules.sops
      inputs.qmd.homeModules.default
    ]
    ++ lib.optionals (!isHeadless) [
      ./chromium
      ./hyprland
      ./quickshell
      ./wallpaper
      ./zen
      ./swaync.nix
      inputs.zen-browser.homeModules.beta
    ]
    ++ lib.optionals (!isHeadless && transcribeEnabled) [ ./transcribe ]
    ++ lib.optionals (!isHeadless && dictateEnabled) [ ./dictate ]
    ++ lib.optionals (isLinux && syngoEnabled) [ ./syngo ];

    home.username = "wesbragagt";
    home.homeDirectory = homeDirectory;
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;
    programs.qmd.enable = true;
    wes.claudeCode = {
      enable = claudeCodeEnabled;
      aliases = {
        ccd = "claude --dangerously-skip-permissions";
      };
    };

    wes.omp.enable = ompEnabled;
    home.packages = [ pkgs.nssTools ];

  }
  // lib.optionalAttrs isLinux {
    systemd.user.services.caddy-local-trust = lib.mkIf (!isHeadless) {
      Unit = {
        Description = "Import Caddy local CA into Chromium trust store";
        ConditionPathExists = "/run/caddy-local-root.crt";
        After = [ "graphical-session.target" ];
        Wants = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = pkgs.writeShellScript "import-caddy-local-ca" ''
          set -eu
          root_ca=/run/caddy-local-root.crt
          nssdb="$HOME/.pki/nssdb"

          for attempt in $(seq 1 30); do
            if [ -s "$root_ca" ]; then
              break
            fi
            sleep 2
          done

          test -s "$root_ca"
          mkdir -p "$nssdb"

          if [ ! -f "$nssdb/cert9.db" ]; then
            certutil -N -d "sql:$nssdb" --empty-password
          fi

          certutil -D -d "sql:$nssdb" -n "Caddy Local Authority" >/dev/null 2>&1 || true
          certutil -A -d "sql:$nssdb" -n "Caddy Local Authority" -t "CT,C,C" -i "$root_ca"
        '';
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
  desktop = {
    gtk = {
      enable = true;
      theme = {
        name = "Orchis-Dark";
        package = pkgs.orchis-theme;
      };
      iconTheme = {
        name = "Papirus";
        package = pkgs.papirus-icon-theme;
      };
    };

    home.pointerCursor = {
      name = "capitaine-cursors";
      package = pkgs.capitaine-cursors;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

  };
in
if isHeadless then base else lib.recursiveUpdate base desktop
