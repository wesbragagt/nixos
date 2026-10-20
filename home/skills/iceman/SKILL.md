---
name: iceman
description: Use the iceman CLI to create and edit Nix flake development environments, find nixpkgs packages, or install iceman guidance into a project. Activate when a user wants a reproducible project dev shell or needs to change its flake dependencies.
---

# Iceman

Use `iceman` for project development environments rather than hand-writing the standard flake-utils `mkShell` template.

## Commands

```bash
iceman init [directory] [-d description] [-p pkg1,pkg2] [-i] [-direnv=false]
iceman add [package...] [-f flake.nix] [-i]
iceman search [query] [--json] [--limit N] [--refresh]
iceman skill [directory] [-file AGENTS.md] [-force]
```

## Workflow

- Start a project environment with `iceman init -p go,gopls,git myproject`; run this from the directory where the new project should be created.
- `init` writes `flake.nix` and `.envrc` (`use flake`). If direnv is installed, it runs `direnv allow`. Use `-direnv=false` to skip `.envrc`.
- Add dependencies from a project directory with `iceman add ripgrep`. It finds the nearest `flake.nix` by searching parent directories. Use `-f` to specify a file.
- Find nixpkgs attribute names with `iceman search <query>`. Results rank package-name matches above description matches.
- With no packages, `iceman search` and `iceman add -i` open an interactive picker. `iceman init -i` opens one when package arguments are omitted. Use arrows to move, space to select, enter to confirm, and escape to cancel.
- Run `nix develop` to enter an initialized environment.
- To teach project coding agents these conventions, run `iceman skill [directory]`. It writes an `AGENTS.md` and refuses to overwrite an existing file unless `-force` is passed. Review the generated file before using `-force`.

## Requirements and behavior

- `init` and `add` edit text and do not require Nix.
- `search` and interactive package selection require `nix` on PATH with flakes enabled. The first package catalog fetch can take a couple of minutes. Cached data lives under `$XDG_CACHE_HOME/iceman/nixpkgs-search.json` for 24 hours; `--refresh` fetches again.
- Non-interactive `add` and `search` commands do not open a picker when stdout is not a terminal.
- `iceman` is installed in this NixOS/Home Manager setup through the flake input `github:wesbragagt/iceman`.
