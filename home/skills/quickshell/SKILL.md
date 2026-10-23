---
name: quickshell
description: Develop, edit, debug, and operate the user's Quickshell bar and QML widgets in nixos-config. Use for Quickshell widgets, panels, popups, status badges, hot reload, and the managed quickshell service.
---

# Quickshell widgets

## Working files

- Repo root is `~/nixos-config`. Home Manager wiring lives in `home/quickshell/default.nix`.
- Root `home/quickshell/config/shell.qml` owns one ordinary shared State per feature outside `Variants`, and creates `layouts/Bar.qml` per physical screen through `Quickshell.screens`. Layout owns only window geometry, placement, dependency forwarding, and local popup focus. Keep this lifecycle: monitor removal destroys widgets, not shared collectors/history.
- `features/<feature>/Widget.qml` owns presentation/local interaction; `State.qml` owns data, parsing, polling and actions. Network uses `features/network/{NetworkWidget,NetworkState,NetworkPanel}.qml`. Do not restore obsolete root Bar/NetworkPanel files.
- `shared/Theme.qml` is the only singleton and owns colors/fonts. `shared/Badge.qml`, `Label.qml`, and `CommandRunner.qml` own reusable visuals/process behavior. Other State and dependencies are explicitly injected.
- `~/.config/quickshell` resolves through Home Manager's `mkOutOfStoreSymlink` to the repo's `home/quickshell/config` directory. Edit the working-tree files, not a Nix store copy or `/tmp/quickshell`.
- Shared skill source is `home/skills/quickshell/SKILL.md`. Home Manager exposes it through `~/.claude/skills`, also used by OMP.

## Hot reload first

Quickshell watches its QML configuration and hot reloads edits while running. Normal widget changes do not need a Nix rebuild, service restart, or another `qs` process. Save the file, observe the running bar, and check the journal for `Configuration Loaded` or QML errors. A failed reload may leave the previous UI running, so a visible bar alone does not prove the edit loaded.

Use `systemctl --user restart quickshell.service` only for a stopped or stuck process, or to apply changed service environment. Reload reconstructs QML objects; treat widget-local state and child processes as transient. Keep persistent actions in the existing services, not in reload-time initialization.

Package, Home Manager, and service changes require `git add -A` followed by `rebuild`. `rebuild build` builds without activating. Never hardcode a host or substitute `nixos-rebuild` for the repo's host-detecting command.

## Develop a widget

1. Read the relevant feature, layout and shared module before editing. Preserve badge colors, spacing, font and interactions unless asked. Put reusable helpers in `shared/`, not beside `shell.qml`; component filenames start with a capital letter.
2. Follow Layout <- Widget <- State <- Process for data and Widget -> State -> runner/native source for actions. Widgets receive State (`featureState`, or network's `networkState`); they do not execute/parse commands or reference native providers/private layout IDs. Reuse shared Badge/Label and Theme. Workspace/clock States inject native sources (Hyprland/SystemClock defaults), not CLI polls.
3. Inject a separate `Shared.CommandRunner` per independent operation into State. Use `start(argv, stdin?, environment?)` and `launchDetached(argv, environment?)`; commands are argument arrays, busy starts skip without overlap, and `completed(result)` publishes fully collected stdout/stderr, exitCode/exitStatus/failedToStart. The runner supplies English `LC_ALL=C.UTF-8`; never put secrets in argv/logs/files/shared properties. Network passwords are transient stdin, cleared locally on send, close or cancel. Shared network scan/connection/radio state must not absorb monitor-local popup visibility, selection, password, reveal or focus. Each open popup registers scan demand; one closing must not stop another's scan timer.
4. Reuse `idle-control status/toggle` for idle behavior so the badge agrees with Super+Shift+I. Use `transcribe status/toggle` only when `QUICKSHELL_TRANSCRIBE=1`; the transcription service owns recording. Preserve host feature gating. Use the English UTF-8 service locale for parsed command output.
5. Save and verify hot reload, then exercise the changed interaction on the real desktop. Check empty, unavailable, or disconnected states relevant to the widget. Do not toggle connectivity, lock the session, or start recording merely to test rendering. Do not claim unexercised behavior works.

Microphone `features/microphone/State.qml` calls `mic-noise status/toggle/preset/restart`; `home/mic-noise/` owns the independent audio service and virtual `CleanMicrophone` source. Preserve raw passthrough when disabled and shared state across monitors. Never start capture from QML initialization. The runtime model download is pinned and hash-checked; weights stay outside the repo and Nix closure. Settings and verified model cache survive UI reloads.

## Controlled behavior checks

From the repository root, run `home/quickshell/config/tests/run` for the complete suite. Optional scenario arguments are `runner helpers core network layout`. It uses installed Quickshell with an offscreen platform and software rendering; `behavior.qml` is the test-only entrypoint, not a second desktop bar. Real runner fixtures are harmless; mutation tests use `tests/FakeRunner.qml` and synthetic credentials only.

Inject runners and native workspace/clock sources before construction, and set `pollingEnabled: false` on polling States before creation. This suppresses automatic initial/timer commands; explicit `refresh()` and actions remain usable. Production status timers run every two seconds; network scan cadence is ten seconds while any popup is open. Shared State survives widget recreation, but full reload reconstructs it. Test meaningful transitions, failures, busy exclusion and shared lifetime; offscreen tests do not prove real Wayland focus or rendering.

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

The bar has launcher, workspaces, resource usage, volume, idle, optional transcription, network settings, Bluetooth status, clock, and session locking. All bars display every workspace and globally focused highlighting. Waybar's media, laptop battery, notifications, and system tray widgets are not yet ported. Do not silently restore Waybar or claim those widgets exist. Add them only when requested, using the same live-edit workflow.
