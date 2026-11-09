---
title: Alt/Super swap and keyboard compatibility
date: 2026-11-09
status: active
tags:
  - type/note
  - keyboard
  - hyprland
  - nixos
---

# Alt/Super swap and keyboard compatibility

## Current config

The swap is per keyboard. Each host lists the keyboards that swap left Alt and
left Super with `hostProfile.swapAltSuperKeyboards` in `flake.nix`. Every other
keyboard keeps its native keys. The default is `[ ]`, so no keyboard swaps.

| Host | Keyboards |
|---|---|
| `iceflake` | `32ac:0012` (Framework Laptop 16 ANSI keyboard module) |
| `nixos-hp` | `0001:0001` (built-in AT Translated Set 2 keyboard) |
| `icebox` | none |

`modules/keyboard.nix` renders the swap as a keyd config whose `ids` are that
list. keyd prefers explicit IDs over the `*` default config, so listed keyboards
get the swap plus the shared Caps Lock mapping. Hyprland has no `kb_options`
swap. keyd grabs every keyboard and re-emits through `keyd-virtual-keyboard`, so
Hyprland per-device rules cannot see which physical keyboard sent a key.

## Find a keyboard ID

```bash
grep -A1 -B1 'Name=' /proc/bus/input/devices
```

Use the `Vendor` and `Product` values from the `I:` line as `vendor:product`.
`sudo keyd monitor` prints the same ID while you press keys.

## Disable the swap on a host

Remove `swapAltSuperKeyboards` from that host profile, or set it to `[ ]`.
