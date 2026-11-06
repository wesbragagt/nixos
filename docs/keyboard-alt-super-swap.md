---
title: Alt/Super swap and keyboard compatibility
date: 2026-05-06
status: active
tags:
  - type/note
  - keyboard
  - hyprland
  - nixos
---

# Alt/Super swap and keyboard compatibility

## Current config

Hosts opt into or out of the swap with `hostProfile.swapAltSuper` in `flake.nix`.

`iceflake` enables the swap in its `flake.nix` host profile. Do not set
`defaultHostProfile` in a host module; it is not a NixOS option.

When enabled, the generated Hyprland config contains:

```ini
kb_options = altwin:swap_lalt_lwin
```

`home/hyprland/default.nix` now renders a single `~/.config/hypr/hyprland.conf`
from shared config text plus a few host-profile conditionals:

- `swapAltSuper` controls whether `kb_options` is emitted
- `isLaptop` controls the monitor line
- `hasWireless` controls whether `nm-applet` autostarts

## Potential problem

This swap is global from Hyprland's point of view. It does not mean “only do this on keyboards that have a Windows key.” It means “swap the left Alt key and the left Super key on keyboards as exposed to Hyprland.”

That can be surprising on keyboards that do not use Windows-key labeling.

## What happens on Apple-style keyboards

On Linux, an Apple keyboard's **Command** key is commonly exposed as **Super/Meta**.

If that is true for a given device, then this setting will usually cause:

- **Left Option** to behave like **Super**
- **Left Command** to behave like **Alt**

So the current config can unintentionally swap **Option** and **Command** on Apple-style keyboards.

## Important limitation

Software usually cannot directly determine whether a keyboard physically has a “Windows key.”

What it can usually see is:

- the host machine
- the keyboard device identity
- the key capabilities or events reported by the driver

That means “has a Windows key” is really approximated as “reports a Super/Meta key,” which is not exactly the same thing.

## Safer ways to scope this in the future

### 1. Host-based scoping

Best when the behavior should differ by machine.

Use this when the built-in keyboard on one host should get the swap, but another host should not.

### 2. Device-based scoping

Best when the behavior should differ by keyboard model.

Use this when an external keyboard should get the swap, but an Apple keyboard or another model should not.

### 3. Capability-based scoping

Possible, but weaker.

This checks whether the device reports Super/Meta-related capabilities or events. It is the closest automatic approximation of “has a Windows key,” but it is still heuristic.

## Recommendation for this repo

If this becomes a real issue, prefer:

1. **host-based scoping** if the difference is really between machines
2. **device-based scoping** if the difference is really between keyboard models

Automatic capability detection should be treated as a fallback, not the first choice.

## Practical takeaway

The Hyprland setting is safe only on hosts where every target keyboard should swap **left Alt** and **left Super**.

For machines or keyboards that should keep their native Alt/Command/Super behavior, set this in the host profile:

```nix
swapAltSuper = false;
```
