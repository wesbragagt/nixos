{
  pkgs,
  inputs,
  lib,
  hostSystem,
  hostProfile ? { },
  ...
}:
let
  isLinux = lib.hasSuffix "-linux" hostSystem;
  isLaptop = hostProfile.isLaptop or false;
  hasWireless = hostProfile.hasWireless or false;
  # Desktop/Wayland tooling only makes sense on a Linux host with a display.
  isHeadless = (hostProfile.headless or false) || !isLinux;
  gamingEnabled = (hostProfile.features or { }).gaming or false;
  mnemosyneEnabled = (hostProfile.features or { }).mnemosyne or false;
  ffmpegEnabled = (hostProfile.features or { }).ffmpeg or false;
  piCodingAgentEnabled = (hostProfile.features or { }).pi-coding-agent or false;
  codexEnabled = (hostProfile.features or { }).codex or true;
  t3codeEnabled = (hostProfile.features or { }).t3code or true;
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  # Python wheels loaded via the Nix-managed interpreter use dlopen(), so they
  # need LD_LIBRARY_PATH directly; nix-ld alone only helps foreign executables.
  wrappedPython =
    if isLinux then
      pkgs.symlinkJoin {
        name = "python3-wrapped";
        paths = [ pkgs.python3 ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for bin in "$out"/bin/python*; do
            if [ -f "$bin" ] && [ -x "$bin" ]; then
              wrapProgram "$bin" --prefix LD_LIBRARY_PATH : /run/current-system/sw/share/nix-ld/lib
            fi
          done
        '';
      }
    else
      pkgs.python3;
  forgejoHost = "forgejo.dory-pentatonic.ts.net";
  # fj has no env-var token support, so log in from the sops secret on first use.
  fj = pkgs.writeShellApplication {
    name = "fj";
    runtimeInputs = [ pkgs.forgejo-cli ];
    text = ''
      host="${forgejoHost}"
      token_file=/run/secrets/forgejo_token
      if [[ -r "$token_file" ]] && ! fj auth list 2>/dev/null | grep -q "@$host$"; then
        fj --host "$host" auth add-key wesbragagt "$(< "$token_file")" >/dev/null
      fi
      for arg in "$@"; do
        [[ "$arg" == -H || "$arg" == --host || "$arg" == --host=* ]] && exec fj "$@"
      done
      exec fj --host "$host" "$@"
    '';
  };
  clipboardSelector = pkgs.writeShellScriptBin "clipboard-selector" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        pkgs.cliphist
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.rofi
        pkgs.wl-clipboard
      ]
    }:$PATH

    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/clipboard-selector"
    mkdir -p "$cache_dir"

    list_entries() {
      cliphist list | while IFS= read -r entry; do
        if grep -Eq '\[\[ binary data .* (png|jpe?g|gif|webp|bmp|tiff|svg)' <<<"$entry"; then
          id="''${entry%%$'\t'*}"
          format="$(grep -Eo '(png|jpe?g|gif|webp|bmp|tiff|svg)' <<<"$entry" | head -n1)"
          case "$format" in
            jpg|jpeg) mime="image/jpeg"; extension="jpg" ;;
            svg) mime="image/svg+xml"; extension="svg" ;;
            *) mime="image/$format"; extension="$format" ;;
          esac
          thumbnail="$cache_dir/$id.$extension"

          if [ ! -s "$thumbnail" ]; then
            printf '%s' "$id" | cliphist decode >"$thumbnail" || rm -f "$thumbnail"
          fi

          image_details="$(grep -Eo '[0-9]+ KiB [^]]+' <<<"$entry" | head -n1)"
          label="$id	🖼 $image_details"

          if [ -s "$thumbnail" ]; then
            printf '%s\0icon\x1f%s\n' "$label" "$thumbnail"
          else
            printf '%s\n' "$label"
          fi
        else
          printf '%s\n' "$entry"
        fi
      done
    }

    selection="$(list_entries | rofi -dmenu -i -show-icons -p clipboard -no-custom -theme-str 'element-icon { size: 96px; }')"
    [ -n "$selection" ] || exit 0

    id="''${selection%%$'\t'*}"

    if grep -Eq '^[0-9]+$' <<<"$id" && grep -Eq '🖼 .*(png|jpe?g|gif|webp|bmp|tiff|svg)' <<<"$selection"; then
      format="$(grep -Eo '(png|jpe?g|gif|webp|bmp|tiff|svg)' <<<"$selection" | head -n1)"
      case "$format" in
        jpg|jpeg) mime="image/jpeg" ;;
        svg) mime="image/svg+xml" ;;
        *) mime="image/$format" ;;
      esac
      printf '%s' "$id" | cliphist decode | wl-copy --type "$mime"
    else
      printf '%s\n' "$selection" | cliphist decode | wl-copy
    fi
  '';
in

{
  xdg.configFile."glow/glow.yml".text = ''
    # The glow-review popup provides the centered document area.
    style: "auto"
    mouse: true
    pager: false
    width: 100
    all: false
    preserveNewLines: true
  '';
  home.packages =
    with pkgs;
    [
      # cli tools
      inputs.exacli.packages.${hostSystem}.default
      gh
      fj
      jq
      yq-go
      go
      fd
      sesh
      uv
      pnpm
      wrappedPython
      stow
      unzip
      tldr
      (
        (pkgs.callPackage "${inputs.nur-combined}/repos/sikmir/pkgs/by-name/re/revdiff/package.nix" {
          buildGoModule = pkgs.buildGo126Module;
        }).overrideAttrs
        (_old: {
          allowGoReference = true;
        })
      )
      (pkgs.callPackage ../../pkgs/excalidraw-cli { })

      # secrets / auth
      libsecret

      # data
      csvlens # interactive CSV viewer
      harlequin # terminal database UI

      # git
      lazygit
      delta

      # markdown viewing
      glow
      (pkgs.writeShellScriptBin "glow-review" (builtins.readFile ../../scripts/glow-review.sh))
      (pkgs.writeShellScriptBin "markdown-fzf" (builtins.readFile ../../scripts/markdown-fzf.sh))

      # scripts
      (pkgs.writeShellScriptBin "file-fzf" (builtins.readFile ../../scripts/sf.sh))
      (pkgs.writeShellScriptBin "grep-fzf" (builtins.readFile ../../scripts/sg.sh))
      (pkgs.writeShellScriptBin "agent-notify" (builtins.readFile ../../scripts/agent-notify.sh))
      (pkgs.writeShellScriptBin "omp-prewalk" (builtins.readFile ../../scripts/omp-prewalk.sh))
      (pkgs.callPackage ../../pkgs/workmux { })
      (pkgs.callPackage ../../pkgs/wtask { })
    ]
    ++ lib.optionals isLinux [
      # linux-only cli tools (nix-ld / x86_64 binaries / linux-specific packaging)
      (pkgs.callPackage ../../pkgs/tuicr { })
      libnotify
      libsecret
      (pkgs.callPackage ../../pkgs/agent-browser { })
      (pkgs.callPackage ../../pkgs/duckdb-bin-1_5_3 { }) # in-process analytical SQL
    ]
    ++ lib.optionals (!isHeadless) [
      # wayland / audio
      pavucontrol
      clipboardSelector
      wl-clipboard
      cliphist
      wlr-randr

      # screenshot / recording
      grim
      slurp
      swappy
      wf-recorder

      # secrets / auth
      bitwarden-desktop

      # desktop / ui
      chromium
      gtk3
      nwg-dock-hyprland
      rofi-calc
      waypaper
      swww
      blueman
      slack
      unstable.signal-desktop
      libreoffice-fresh
      (symlinkJoin {
        name = "dbeaver-bin-x11";
        paths = [ dbeaver-bin ];
        nativeBuildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/dbeaver" \
            --set GDK_BACKEND x11 \
            --set SWT_GTK3 1
        '';
      }) # desktop database client; force XWayland to avoid SWT dialog issues on Hyprland

      # media
      playerctl
      mpv
      imv

      # scripts
      (pkgs.writeShellScriptBin "rofi-bookmarks" (builtins.readFile ../../scripts/rofi-bookmarks.sh))
      (pkgs.writeShellScriptBin "edit-bookmarks" (builtins.readFile ../../scripts/edit-bookmarks.sh))
      (pkgs.writeShellScriptBin "rofi-freq" (builtins.readFile ../../scripts/rofi-freq.sh))
      (pkgs.writeShellScriptBin "wf-record" (builtins.readFile ../../scripts/wf-recorder.sh))
      (pkgs.writeShellScriptBin "wf-record-region" ''exec wf-record region "$@"'')
    ]
    ++ lib.optionals (hasWireless && !isHeadless) [
      # network / Wi-Fi tray helpers
      networkmanagerapplet
      iwgtk
    ]
    ++ lib.optionals (isLinux && isLaptop) [
      (pkgs.writeShellScriptBin "battery-estimate" (builtins.readFile ../../scripts/battery-estimate.sh))
    ]
    ++ lib.optionals (gamingEnabled && !isHeadless) [
      # gaming (feature-flagged; enable via /etc/nixos/features.yaml)
      lutris
      wineWowPackages.stable
      winetricks
    ]
    ++ lib.optionals mnemosyneEnabled [
      (pkgs.callPackage ../../pkgs/mnemosyne { })
    ]
    ++ lib.optionals ffmpegEnabled [
      ffmpeg
    ]
    ++ lib.optionals piCodingAgentEnabled [
      (pkgs.callPackage ../../pkgs/pi-coding-agent { bun-bin-1_4_2 = pkgs.callPackage ../../pkgs/bun-bin-1_4_2 { }; })
    ]
    ++ lib.optionals codexEnabled [
      unstable.codex
    ]
    ++ lib.optionals t3codeEnabled [
      (unstable.symlinkJoin {
        name = "t3code";
        paths = [
          (unstable.callPackage ../../pkgs/t3code {
            t3codeSrc = inputs.t3code-src;
          })
        ];
        nativeBuildInputs = [ unstable.makeBinaryWrapper ];
        postBuild = ''
          for program in "$out/bin"/*; do
            wrapProgram "$program" --prefix PATH : "${unstable.lib.makeBinPath [
              (pkgs.callPackage ../../pkgs/claude-code { })
              unstable.codex
            ]}"
          done
        '';
      })
    ];

}
