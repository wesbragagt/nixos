# nixos-config

NixOS + home-manager flake. Per-host system configs under `hosts/`, shared base in `common.nix`, user/dotfiles in `home/`.

## Quick start: new NixOS system

From the live ISO, after disks are partitioned, formatted, and mounted at `/mnt`:

```bash
# 1. Network
sudo systemctl start NetworkManager   # or `wpa_supplicant` / `iwctl` for wifi

# 2. Generate hardware config for THIS machine
sudo nixos-generate-config --root /mnt

# 3. Pull this repo
nix-shell -p git --run 'git clone https://github.com/wesbragagt/nixos-config /mnt/etc/nixos'

# 4. Carve out a host directory and move the generated hardware file in
HOST=<newhost>
sudo mkdir -p /mnt/etc/nixos/hosts/$HOST
sudo mv /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/$HOST/

# 5. Create the host's default.nix (copy nixos-hp's, change hostName)
sudo cp /mnt/etc/nixos/hosts/nixos-hp/default.nix /mnt/etc/nixos/hosts/$HOST/default.nix
sudo sed -i "s/nixos-hp/$HOST/" /mnt/etc/nixos/hosts/$HOST/default.nix

# 6. Register the host in flake.nix (add a sibling with mkHost)
#    For a non-laptop desktop without Wi-Fi UI:
#    nixosConfigurations.$HOST = mkHost {
#      name = "$HOST";
#      hostProfile = { isLaptop = false; hasWireless = false; graphics = "generic"; };
#    };

# 7. If using repo secrets, pre-generate target SSH host key, add its age
#    recipient to .sops.yaml, then run sops-updatekeys-all with your YubiKey.
#    This makes the first activation able to decrypt /run/secrets/exa_api_key.
sudo install -d -m 0755 /mnt/etc/ssh
sudo ssh-keygen -t ed25519 -N "" -f /mnt/etc/ssh/ssh_host_ed25519_key
nix-shell -p ssh-to-age --run 'ssh-to-age < /mnt/etc/ssh/ssh_host_ed25519_key.pub'

# 8. Stage flake-visible changes, then install
git -C /mnt/etc/nixos add -A
sudo nixos-install --flake /mnt/etc/nixos#$HOST --root /mnt

# 9. Reboot, log in, then on the running system:
git clone https://github.com/wesbragagt/nixos-config ~/nixos-config
sudo nixos-rebuild switch --flake ~/nixos-config#$HOST
```

After the first switch, `home-manager` activates automatically (it's wired in as a NixOS module). Clone this repo to `~/nixos-config` before first graphical use; Quickshell, Neovim, and rofi use out-of-store links into that working tree for live iteration. Add your SSH public key to `users.users.<you>.openssh.authorizedKeys.keys` in `common.nix` (or per-host) before the next push so passwordless SSH from your other machines works.

## Layout

```
flake.nix                  # nixosConfigurations + homeConfigurations
common.nix                 # shared NixOS base (user, locale, packages, services)
modules/                   # NixOS system modules (graphics, audio, hyprland, ...)
home/                      # home-manager (wesbragagt.nix entry, programs, hyprland, quickshell)
  npm/                     # npm global prefix/session wiring for ~/.npm-global
hosts/
  nixos-hp/
    default.nix            # host-specific (hostname, boot, hardware import)
    hardware-configuration.nix
rofi/                      # rasi themes wired via xdg.configFile
scripts/                   # rofi-freq frequency-sorted launcher
```

## Apply on an existing NixOS box

```bash
cd ~/nixos-config
git add -A   # flake reads from the git tree; untracked files are invisible
rebuild
```

## Quickshell bar

Home Manager installs Quickshell and starts `quickshell.service` with the Hyprland session instead of Waybar. `~/.config/quickshell` uses `mkOutOfStoreSymlink` to point at `home/quickshell/config` in the working tree. Root `shell.qml` owns one shared State per feature outside `Variants` and creates `layouts/Bar.qml` per physical screen. The layout handles only window geometry, placement, dependency forwarding, and local popup focus; monitor removal/recreation does not reset shared data or duplicate collectors.

The bar includes launcher, workspaces, CPU/memory/disk usage, audio controls, idle control, host-enabled transcription, Wi-Fi settings, Bluetooth status, clock, and session locking. Idle control shares `idle-control` with Super+Shift+I. The design does not include Waybar's media, laptop battery, notification, or system tray widgets.

Edit feature presentation and interactions in `features/<feature>/Widget.qml` and data/actions in `State.qml` (network uses `NetworkWidget.qml`, `NetworkState.qml`, and feature-local `NetworkPanel.qml`). Data flows Layout <- Widget <- State <- Process; actions go through State. Network connection/scan data is shared, while popup visibility, selection, password, reveal, and focus are local to each monitor. Credentials use stdin only and clear on send/close/cancel. `shared/Theme.qml` owns colors/fonts; `shared/Badge.qml`, `Label.qml`, and `CommandRunner.qml` supply reusable visuals and independent command runners.

Hover over CPU, memory, or disk badges for details: CPU model/count/usage/load, memory used/available/total, and root filesystem capacity. Each polling State owns its two-second timer and `refresh()`; the shared network scan runs every ten seconds while any popup is open. All bars display all workspaces and global focus. State survives monitor-widget recreation but a full QML reload reconstructs it.

Run `home/quickshell/config/tests/run` from the repository root for all isolated offscreen behavior checks, or pass `runner`, `helpers`, `core`, `network`, or `layout`. Tests inject fake runners/native workspace/clock sources and set `pollingEnabled: false` before State construction, then call refresh/actions explicitly. The suite also exercises harmless actual processes, QtTest pointer gestures, Theme propagation, and two-widget-set lifetimes; it creates no additional desktop bar and performs no real connectivity/lock/recording actions. `behavior.qml` is the test-only entrypoint.

QML edits hot reload without a rebuild or second `qs` process. Check `journalctl --user -u quickshell.service -b -n 60 --no-pager` for a new `Configuration Loaded` and no QML/import errors; a visible old bar alone is not proof. Restart only a stopped/stuck service or after service-environment changes. Exercise safe desktop interactions and use `hyprctl monitors -j`, `hyprctl layers -j`, and geometry-matched `grim` captures; report unavailable image inspection or physical multi-monitor proof explicitly.

### OMP questions

Press Super+/ to toggle the floating question panel on the focused monitor. Enter asks; Shift+Enter inserts a line. Responses stream as selectable Markdown with HTTP(S) source links. Copy answer copies rendered text. Escape/Close hides without cancelling; Stop cancels the request. New question clears the displayed answer, not saved history.

Each submission opens an independent native OMP ACP session pinned to `ccflare/gpt-6-luna` with low thinking effort, regardless of your default model. Normal OMP history stays saved. Tools are limited to web search and HTTP(S) page reads by `features/questions/WebOnly.ts`; this is not an OS sandbox. The service finds `omp` on its PATH; set `QUICKSHELL_OMP` only to override it. Missing executables, protocol errors and deadlines appear in the panel rather than falling back to print mode.

Open History or press Ctrl+H inside the panel to search saved conversations. Search matches question and answer text using all typed words, ignoring case. Use Up/Down and Enter to open a result. Saved answers are read-only and support selection, Copy answer and source links. Return to the current question with Ctrl+H; browsing does not cancel it or replace its answer. History reads the existing JSONL files in `~/.omp/agent/sessions/-/` through a local Bun helper, without a second database. Older panel sessions have no panel marker, so this list also includes other OMP conversations started from your home directory. Repository sessions are not included.

Answers render through `features/questions/Markdown.js`: the vendored `marked` parser produces the HTML subset Qt rich text supports, styled from `shared/Theme.qml` (callout cards for quotes, numbered chips for ordered lists, bordered tables, inline code chips). Source links open in a new Chromium window on the workspace you clicked from. Raw HTML, images and non-HTTP(S) links never reach the view, and the whole answer stays one selectable document. QML's JS engine lacks newer syntax, so `features/questions/vendor/Marked.js` is generated: run `features/questions/vendor/build-marked.sh [version]` to upgrade it (needs network, `npx` and `bun`). Loading it logs about seventeen harmless `usedbeforedeclared` warnings.

Run `home/quickshell/config/tests/run questions questions-errors questions-deadlines questions-transport questions-transport-errors questions-render questions-input questions-markdown questions-history questions-history-ui` for isolated lifecycle, deadlines, process framing, rendering, sanitizing, keyboard, clipboard, history search/loading, native source-link and web-only checks. The complete suite includes these scenarios and a read-only JSONL loader regression check. The screen-lifetime fixture requires Wayland: `QT_QPA_PLATFORM=wayland QUICKSHELL_TEST_SCENARIO=questions-window quickshell --path home/quickshell/config/behavior.qml`.

### Microphone noise suppression

Click the microphone badge beside speaker volume to enable suppression, use raw bypass, choose Light/Balanced/Strong, or restart a failed processor. Select `CleanMicrophone` in the calling app; this feature does not change your system default input. `mic-noise status` reports the processor state. `mic-noise toggle`, `mic-noise preset Balanced`, and `mic-noise restart` provide the same controls from a terminal.

`home/mic-noise/` owns the independent user service and persistent virtual source. FFmpeg processes audio locally with `arnndn`; the three presets blend 50%, 75%, or 100% processed audio. Bypass sends raw microphone audio, not silence or mute. Toggle/preset/source changes restart the FFmpeg stream with a brief interruption while the virtual microphone remains present. Source removal or processor failure produces an error and requires manual restart; there is no automatic retry loop. Do not select a desktop monitor as the physical default source.

On first startup the service downloads the pinned `bd.rnnn` model from [arnndn-models](https://github.com/richardpl/arnndn-models) over HTTPS and verifies SHA-256. It caches the model under `$XDG_CACHE_HOME/mic-noise` and saves settings under `$XDG_STATE_HOME/mic-noise`, defaulting to `~/.cache` and `~/.local/state`. Cached verified weights work offline. The weights are not bundled in the repository or Nix closure. Upstream has no explicit model redistribution license; runtime downloading does not resolve that ambiguity. Audio is streamed only, never saved or uploaded by this feature. Suppression quality and latency depend on the microphone and model; Soundveil-equivalent performance is not claimed.

## npm global packages

npm global installs are routed into `~/.npm-global` by the dedicated Home Manager
module at `home/npm/default.nix`.

It sets:
- `NPM_GLOBAL=$HOME/.npm-global`
- `NPM_CONFIG_PREFIX=$HOME/.npm-global`
- `PATH+=~/.npm-global/bin`

This keeps ad-hoc npm-installed CLIs in a user-owned prefix instead of mixing them
into the system or relying on distro defaults.

## Use on non-NixOS Linux (home-manager standalone)

CLI/dotfile parts of `home/` work on Ubuntu/Arch/etc. The desktop configuration (Hyprland, Quickshell, Thunar) is managed for NixOS hosts.

```bash
nix run home-manager/master -- switch --flake github:wesbragagt/nixos-config#wesbragagt
```

## Per-host SSH

The mac uses `~/.ssh/config`:
```
Host nixos-hp
  HostName <ip>
  User wesbragagt
  IdentityFile ~/.ssh/nixos-hp.key
```
Private key lives in the Bitwarden SSH agent; the matching public key is pinned declaratively in `common.nix` via `users.users.wesbragagt.openssh.authorizedKeys.keys`.

Passwordless sudo for `wheel` is set in `common.nix`.

## Secrets

This repo now includes `sops-nix` scaffolding with an optional repo-shared secrets file:

- `secrets/secrets.yaml`
- repo-level recipient config in `.sops.yaml`

If that file does not exist, the config still evaluates/builds. New hosts can bootstrap with `sopsHostKeyPath = null`; after their SSH host recipient is added to `.sops.yaml` and secrets are re-wrapped, set `sopsHostKeyPath = "/etc/ssh/ssh_host_ed25519_key"` for unattended rebuilds with `/run/secrets/exa_api_key`.
See `secrets/README.md` for the YubiKey + age workflow and `docs/add-another-machine.md` for multi-host setup.
