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

Home Manager installs Quickshell and starts `quickshell.service` with the Hyprland session instead of Waybar. `~/.config/quickshell` uses `mkOutOfStoreSymlink` to point at `home/quickshell/config` in the working tree. `shell.qml` creates a `Bar.qml` for each connected screen and recreates bars when monitors return. Edit widgets in `Bar.qml` and `NetworkPanel.qml`; Quickshell reloads QML changes live. Restart with `systemctl --user restart quickshell` if needed.

The imported bar includes workspaces, CPU/memory/disk usage, audio controls, idle control, host-enabled transcription, Wi-Fi settings, Bluetooth status, clock, temperature, and session locking. Idle control shares `idle-control` with Super+Shift+I. The imported design does not include Waybar's media, laptop battery, notification, or system tray widgets.

Hover over CPU, memory, or disk badges for details. CPU shows its model, logical CPU count, usage, and load averages. Memory shows used, available, and total capacity. Disk shows root filesystem usage and capacity. Values refresh with the bar's two-second resource poll; moving the pointer away dismisses the tooltip.

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
