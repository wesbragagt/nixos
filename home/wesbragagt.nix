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
  mnemosyneEnabled = features.mnemosyne or false;
  transcribeEnabled = features.transcribe or false;
  hunkEnabled = hostProfile.hunkEnabled or true;
  base = {
    imports = [
      ./repo-root.nix
      ./ccflare
      ./claude
      ./omp
      ./programs.nix
      ./tmux
      ./neovim
      ./sops
      inputs.sops-nix.homeManagerModules.sops
      inputs.qmd.homeModules.default
    ]
    ++ lib.optionals hunkEnabled [ inputs.hunk.homeManagerModules.default ]
    ++ lib.optionals (!isHeadless) [
      ./hyprland
      ./waybar
      ./wallpaper
      ./zen
      ./swaync.nix
      inputs.zen-browser.homeModules.beta
    ]
    ++ lib.optionals (!isHeadless && transcribeEnabled) [ ./transcribe ];

    home.username = "wesbragagt";
    home.homeDirectory = homeDirectory;
    home.stateVersion = "25.11";

    programs.home-manager.enable = true;
    wes.claudeCode = {
      enable = claudeCodeEnabled;
      aliases = {
        ccd = "claude --dangerously-skip-permissions";
      };
    };

    wes.omp.enable = ompEnabled;
    home.packages = [ pkgs.nssTools ];
    home.sessionVariables = lib.optionalAttrs mnemosyneEnabled {
      MNEMOSYNE_DATA_DIR = "${homeDirectory}/.local/share/mnemosyne";
      MNEMOSYNE_BANK = "default";
    };

  }
  // lib.optionalAttrs isLinux {
    systemd.user.services.caddy-local-trust = lib.mkIf (!isHeadless) {
      Unit = {
        Description = "Import Caddy local CA into Chromium trust store";
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

    home.packages =
      let
        mkChromiumWebApp = {
          name,
          url,
          port,
          startupWMClass,
          icon,
        }:
        let
          chromium = pkgs.chromium.override {
            commandLineArgs = "--remote-debugging-port=${toString port}";
          };
          launcher = pkgs.writeShellScriptBin "${name}-webapp" ''
            exec ${chromium}/bin/chromium \
              --window-name="${name}" \
              --app=${url} \
              --user-data-dir="$HOME/.config/chromium-webapps/${name}" \
              --no-default-browser-check \
              --disable-features=GlobalShortcutsPortal
          '';
        in
        {
          package = launcher;
          desktopEntry = pkgs.makeDesktopItem {
            inherit name;
            desktopName = name;
            exec = "${launcher}/bin/${name}-webapp";
            categories = [ "Network" "WebBrowser" ];
            inherit startupWMClass;
            inherit icon;
          };
        };
        excalidraw = mkChromiumWebApp {
          name = "Excalidraw";
          url = "https://excalidraw.com";
          port = 9223;
          startupWMClass = "chrome-excalidraw.com__-Default";
          icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/excalidraw.svg";
        };
        roam = mkChromiumWebApp {
          name = "Roam";
          url = "https://ro.am";
          port = 9224;
          startupWMClass = "chrome-ro.am__-Default";
          icon = "chromium";
        };
        whatsapp = mkChromiumWebApp {
          name = "WhatsApp";
          url = "https://web.whatsapp.com";
          port = 9225;
          startupWMClass = "chrome-web.whatsapp.com__-Default";
          icon = "chromium";
        };
        discord = mkChromiumWebApp {
          name = "Discord";
          url = "https://discord.com/app";
          port = 9226;
          startupWMClass = "chrome-discord.com__app-Default";
          icon = "chromium";
        };
      in
      [
        excalidraw.package
        excalidraw.desktopEntry
        roam.package
        roam.desktopEntry
        whatsapp.package
        whatsapp.desktopEntry
        discord.package
        discord.desktopEntry
      ];
  };
in
if isHeadless then base else lib.recursiveUpdate base desktop
