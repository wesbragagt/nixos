#!/usr/bin/env bash
# Regenerates Marked.js, a QML-loadable build of marked (MIT).
# QML's JS engine rejects object spread, optional catch binding, Unicode property
# escapes and Array.prototype.at, so esbuild lowers the syntax and the rest is patched.
set -euo pipefail
version="${1:-15.0.12}"
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL "https://cdn.jsdelivr.net/npm/marked@$version/lib/marked.umd.js" -o "$work/marked.js"
npx --yes esbuild@0.25 "$work/marked.js" --target=es2016 --outfile="$work/lowered.js" --log-level=warning
bun "$here/patch-marked.ts" "$work/lowered.js" "$here/Marked.js" "$version"
