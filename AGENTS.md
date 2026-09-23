# AGENTS.md

Operational checklist for this repo.

## Daily workflow (do this every time)

1. Make changes in the right place (`hosts/`, `modules/`, `home/`, `scripts/`, etc.).
2. Stage everything: `git add -A`.
3. Rebuild **only with the documented `rebuild` command**:
   - Normal switch: `rebuild`
   - Dry run/build: `rebuild build`
   - Other actions: `rebuild test` / `rebuild boot` / `rebuild dry-activate`
   - `rebuild` auto-detects the current host. Do **not** hardcode `.#<host>` in `nixos-rebuild`, `nix build`, validation scripts, or aliases unless the user explicitly asks to target a different machine.
   - Do **not** use scripts or commands that default to a host name (for example `nixos-hp`). Running the wrong NixOS host configuration can be destructive.
   - If `rebuild` is unavailable, stop and ask the user instead of guessing a host or falling back to `nixos-rebuild --flake .#<host>`.
   - Home Manager build only when specifically needed: `nix build .#homeConfigurations.wesbragagt.activationPackage`
4. If it fails, scroll to the **last `error:`** line first.

## High-value reminders

- **Flake only sees git-tracked/staged content**. Untracked edits are invisible.
- **Do not edit** `hosts/*/hardware-configuration.nix` manually.
- **No plaintext secrets in repo**. Encrypted GitOps secrets live in `secrets/secrets.yaml` via `sops-nix`; recipient rules live in `.sops.yaml`.
- For the secrets workflow and setup details, read `secrets/README.md` first, then `docs/sops-yubikey.md` for YubiKey recipient enrollment.
- Prefer **NixOS/Home Manager modules** over raw packages when available.
- Put packages in the right scope:
  - System-wide: `common.nix` / `modules/*.nix`
  - User-only: `home/programs.nix` (`home.packages`)

## Repo map (where to change what)

- `flake.nix` — host entries + standalone HM output
- `common.nix` — shared base (user, ssh, sudo, locale, core packages)
- `modules/*.nix` — system features (graphics/audio/fonts/hyprland/login/keyboard/tailscale)
- `hosts/<host>/default.nix` — host-specific settings
- `home/wesbragagt.nix` — HM entrypoint
- `home/hyprland/` — Hyprland Home Manager wiring; `default.nix` generates `hyprland.conf`, and `hyprlock.conf` is store-managed from the repo file
- `home/waybar/` — Waybar Home Manager wiring; `default.nix` generates the Waybar config and CSS
- `home/neovim/` — Neovim Home Manager wiring + config + `lsp-registry.json`
- `home/tmux/` — tmux Home Manager wiring + `tmux.conf`
- `home/programs.nix` — user program module imports
- `home/npm/` — npm global prefix/session wiring for `~/.npm-global`
- `scripts/` + `rofi/` — launcher scripts and themes
- `secrets/README.md` — canonical secrets setup and GitOps workflow
- `docs/sops-yubikey.md` — add/update YubiKey recipients for SOPS
- `docs/add-another-machine.md` — comprehensive multi-host machine onboarding guide

## Module structure conventions

- Keep **system-level concerns** in `modules/`:
  - NixOS services
  - PAM/polkit/udev
  - system packages
  - host-wide session/platform settings
- Keep **user-level concerns** in `home/`:
  - Home Manager modules
  - user packages
  - dotfiles and app config
  - launcher/theme/editor/user-session wiring
- Organize by **feature/domain**, not by file type, once a feature has more than one file.
  - Good: `home/hyprland/default.nix` + nearby supporting files like `hyprlock.conf`
  - Good: `home/waybar/default.nix` generating the runtime config/CSS from Nix
- Use `default.nix` as the feature entrypoint when a module owns multiple related files.
- Keep top-level entrypoints thin:
  - `common.nix` imports system modules
  - `home/wesbragagt.nix` imports Home Manager feature modules
- Keep runtime-editable config files next to the module that wires them.
- Do not move user config into `modules/` just because it is desktop-related; `modules/` and `home/` stay separate by ownership.

## Common action items

### Add a new host

Follow `docs/add-another-machine.md` for the full multi-host + secrets workflow.

1. Create `hosts/<newhost>/`
2. Copy machine-generated `hardware-configuration.nix` there
3. Copy `hosts/nixos-hp/default.nix` → `hosts/<newhost>/default.nix`, update `networking.hostName`
4. Add `nixosConfigurations.<newhost>` in `flake.nix`
5. If the machine should decrypt shared secrets, add its host SSH recipient to `.sops.yaml` and run `sops-updatekeys-all`
6. On the new host: `git add -A && rebuild`

### Add a package

- User package first: `home/programs.nix`
- System package only when system integration is needed

### npm global packages

- npm global CLI installs are intentionally routed to `~/.npm-global`
- Session variables and PATH wiring live in `home/npm/default.nix`
- Keep npm global prefix setup there instead of duplicating it in shell modules

### Schedule a cron job

Use the `schedules` CLI. It takes effect at once. Do **not** run `rebuild` for a job.

```bash
schedules add <name> --schedule "0 3 * * *" --command "./scripts/sync.sh" --cwd /path/to/project
schedules run <name>      # run it now, with the same environment cron uses
schedules logs <name>     # read collected output
schedules list            # every job
schedules remove <name>
```

- Always verify with `schedules run <name>` before you report the job as done.
- `--schedule` takes the 5 standard cron fields. `--cwd` defaults to the current directory.
- Add `--tmux` to run the job as a window named `<name>` in the shared `schedules` tmux session. Attach with `tmux attach -t schedules`.
- Jobs live in `~/.local/state/schedules/jobs/`. Logs live in `~/.local/state/schedules/logs/`.
- The CLI owns a marked block in the user crontab. Hand-written crontab lines are kept.
- Source: `home/schedules/schedules.py`. `modules/cron.nix` enables cron and user linger.

### Use flake inputs in `home/`

- Ensure module args include `inputs`:
  `{ pkgs, config, inputs, ... }:`
- Reference package via:
  `inputs.<name>.packages.${pkgs.stdenv.hostPlatform.system}.default`

## Desktop iteration shortcuts

- Reload Hyprland: `hyprctl reload`
- Restart Waybar: `pkill waybar && hyprctl dispatch exec waybar`
- Restart dock: `pkill nwg-dock && hyprctl dispatch exec "nwg-dock-hyprland ..."`
- Cursor changes: `hyprctl setcursor <theme> <size>`

## Environment-specific notes

- Do not assume the active host from this file. Check `hostname` if needed, but still use only `rebuild` so host selection follows the repo's documented command.
- `allowUnfree = true` is enabled
- Passwordless sudo for `wheel` is enabled
- SSH authorized key for `wesbragagt` is pinned in `common.nix`
- DHCP IP may change; update SSH host alias/known_hosts as needed

## Web apps (Chromium-based)

Managed declaratively via the `chromium-webapps` home-manager module
(`github:chobbledotcom/nix-chromium-webapps`, wired in `flake.nix` and
`home/wesbragagt.nix`).

### Add a new web app

Edit `home/wesbragagt.nix` → `programs.chromium-webapps.webApps`:

```nix
{
  name = "AppName";
  url = "https://app.example.com";
  icon = papirusIcon "com.example.AppName"; # optional
}
```

The module generates a `.desktop` entry with a unique `WM_CLASS`,
isolates the profile under `~/.config/chromium-webapps/<name>/`, and
auto-converts the icon path to all needed sizes.

### Icon lookup (Papirus)

```bash
find /nix/store/*papirus*/share/icons/Papirus/64x64/apps -name '*.svg' | grep -i <app>
```

Then pass the basename (without `.svg`) to the `papirusIcon` helper
defined in `home/wesbragagt.nix`.

### Why Widevine matters

Spotify (and other DRM-protected web players) need Widevine. NixOS
Chromium does not include Widevine by default, so we override it in
`common.nix`:

```nix
nixpkgs.overlays = [
  (final: prev: {
    chromium = prev.chromium.override { enableWideVine = true; };
  })
];
```

Without this, Spotify Web silently plays no audio (player runs, no
sound). Slack, Meet, ro.am, etc. work without Widevine.

### Why not `programs.chromium`

Both `programs.chromium` and the webapps module add Chromium to the
environment. Enabling both creates two derivations of the same
Chromium version (the home-manager module wraps it differently),
which fails with `pkgs.buildEnv: two given paths contain a conflicting
subpath`. Wayland is enabled instead via `NIXOS_OZONE_WL=1` in
`modules/hyprland.nix`.

### Removing the native client when a webapp covers it

Native + webapp produces duplicate launcher entries. Remove the
native package from `home/programs.nix` once the webapp is verified.
