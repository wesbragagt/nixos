---
title: Bootstrap a macOS laptop with this flake
date: 2026-08-02
status: active
tags:
  - type/how-to
  - nix
  - darwin
  - macos
---

# Bootstrap a macOS laptop with this flake

This repo has a shared Darwin bootstrap target:

```nix
.#darwinConfigurations.macos
```

Use it when you want a new Mac to get the same terminal/dev setup as Linux, including:

- shell config
- git
- tmux
- neovim
- Claude Code
- pi

It intentionally does **not** install the Linux desktop stack.

## Assumptions

- the Mac is Apple Silicon (`aarch64-darwin`)
- you want the shared bootstrap profile, not a machine-specific host yet
- the repo is cloned to:

```bash
~/nixos-config
```

That path matters because some repo-managed config points at `${config.home.homeDirectory}/nixos-config`.

## What `macos` means

`macos` is the **flake host name**, not the machine's real hostname.

The laptop can keep whatever macOS computer name/LocalHostName it already has. The flake target stays:

```bash
.#macos
```

## 1. Install Nix

Install Nix first using your preferred installer.

## 2. Clone this repo to the expected path

```bash
git clone <your-repo-url> ~/nixos-config
cd ~/nixos-config
```

## 3. Optional: set up SOPS access first

If you want shared secrets to work on macOS, read:

- `secrets/README.md`
- `docs/sops-yubikey.md`

At minimum, this repo expects SOPS age identities in:

```bash
~/.config/sops/age/keys.txt
```

If you do not need shared secrets immediately, you can bootstrap first and add them afterward.

## 4. Stage the repo contents

The flake only sees tracked/staged content:

```bash
git add -A
```

## 5. Validate the Darwin build

```bash
nix build .#darwinConfigurations.macos.config.system.build.toplevel
```

## 6. First switch on a new Mac

If `darwin-rebuild` is not installed yet, use:

```bash
nix run github:nix-darwin/nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake .#macos
```

## 7. Subsequent rebuilds

After the first switch, open a new shell in `~/nixos-config` and use:

```bash
rebuild build
rebuild
```

The repo shell config targets the managed flake host name `macos`, so rebuilds do not depend on the laptop's actual hostname.

## What to expect after bootstrap

You should get the shared dev environment, including:

- `nvim`
- `tmux`
- `gh`
- `uv`
- `pnpm`
- `claude`
- `pi`

## When to create a real per-machine host

Stay on `macos` if every Mac should get the same bootstrap profile.

Create a dedicated Darwin host later if a machine needs unique settings, for example:

- different packages
- different secrets behavior
- machine-specific defaults

At that point, add a new `hosts/<name>/` entry and a sibling `darwinConfigurations.<name>` output, and keep `macos` as the generic bootstrap target.
