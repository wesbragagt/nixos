---
name: quickshell
description: Develop, edit, debug, and operate the user's Quickshell bar and QML widgets in nixos-config. Use for Quickshell widgets, panels, popups, status badges, hot reload, and the managed quickshell service.
---

# Quickshell widgets

## Working files

- Repo root is `~/nixos-config`. Home Manager wiring lives in `home/quickshell/default.nix`.
- `home/quickshell/config/shell.qml` creates one `Bar.qml` per screen through `Variants` and `Quickshell.screens`. Edit bar widgets in `Bar.qml`; `NetworkPanel.qml` owns the Wi-Fi popup. Keep this per-screen lifecycle so bars are recreated when monitors return.
- `~/.config/quickshell` resolves through Home Manager's `mkOutOfStoreSymlink` to the repo's `home/quickshell/config` directory. Edit the working-tree files, not a Nix store copy or `/tmp/quickshell`.
- Shared skill source is `home/skills/quickshell/SKILL.md`. Home Manager exposes it through `~/.claude/skills`, also used by OMP.

## Hot reload first

Quickshell watches its QML configuration and hot reloads edits while running. Normal widget changes do not need a Nix rebuild, service restart, or another `qs` process. Save the file, observe the running bar, and check the journal for `Configuration Loaded` or QML errors. A failed reload may leave the previous UI running, so a visible bar alone does not prove the edit loaded.

Use `systemctl --user restart quickshell.service` only for a stopped or stuck process, or to apply changed service environment. Reload reconstructs QML objects; treat widget-local state and child processes as transient. Keep persistent actions in the existing services, not in reload-time initialization.

Package, Home Manager, and service changes require `git add -A` followed by `rebuild`. `rebuild build` builds without activating. Never hardcode a host or substitute `nixos-rebuild` for the repo's host-detecting command.

## Develop a widget

1. Read the current QML and module before editing. Preserve the existing badge colors, spacing, font, and interactions unless asked to change them. Keep reusable QML components beside `shell.qml`; component filenames start with a capital letter.
2. Use Qt Quick bindings for derived display values, explicit properties for state, and signals for actions. Reuse the existing `Badge` and `Label` components for bar items. Use Quickshell APIs for compositor data, such as `Quickshell.Hyprland`, rather than polling a command when an existing API covers the need. Consult the installed version's API documentation before adding unfamiliar types or properties.
3. For external commands, use `Quickshell.Io.Process` with argument arrays and `StdioCollector` for output. Do not launch overlapping polls; check `running` before starting again. Use `Quickshell.execDetached` for independent app launches. Keep secrets out of command arguments and logs. Declare new runtime packages in `home/quickshell/default.nix`.
4. Reuse `idle-control status/toggle` for idle behavior so the badge agrees with Super+Shift+I. Use `transcribe status/toggle` only when `QUICKSHELL_TRANSCRIBE=1`; the transcription service owns recording. Preserve host feature gating. Use the English UTF-8 service locale for parsed command output.
5. Save and verify hot reload, then exercise the changed interaction on the real desktop. Check empty, unavailable, or disconnected states relevant to the widget. Do not toggle connectivity, lock the session, or start recording merely to test rendering. Do not claim unexercised behavior works.

## Operate and inspect

```bash
systemctl --user status quickshell.service --no-pager
journalctl --user -u quickshell.service -b -n 60 --no-pager
quickshell list
hyprctl layers -j
readlink -f ~/.config/quickshell
```

The service starts with `hyprland-session.target` and stops with that session. Use `systemctl --user start quickshell.service` if it is stopped. Do not start an additional `qs` instance beside the service; it creates duplicate bars. Inspect `quickshell --help` and subcommand help before targeting an instance with CLI controls. Never kill unrelated Quickshell configurations.

For visual proof, capture the affected monitor or bar with `grim` using its actual geometry from `hyprctl monitors -j`. Inspect the image for clipping, overlap, missing icons, popup anchoring, and workspace state. Check service logs after interactions. If image inspection or input automation is unavailable, state exactly which checks ran and which interactions remain unverified.

## Current scope

The imported bar has workspaces, resource usage, volume, idle, optional transcription, network settings, Bluetooth status, clock, temperature, and session locking. Waybar's media, laptop battery, notifications, and system tray widgets are not yet ported. Do not silently restore Waybar or claim those widgets exist. Add them only when requested, using the same live-edit workflow.
