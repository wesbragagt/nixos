#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
package_dir="$repo_root/pkgs/pi-coding-agent"
package_file="$package_dir/default.nix"
lockfile="$package_dir/package-lock.json"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

version=${1:-$(npm view @oh-my-pi/pi-coding-agent version)}
archive=$(npm pack "@oh-my-pi/pi-coding-agent@$version" --pack-destination "$tmp_dir" --silent)
tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
cp "$tmp_dir/package/package.json" "$tmp_dir/package.json"
(cd "$tmp_dir" && npm install --package-lock-only --ignore-scripts)
cp "$tmp_dir/package-lock.json" "$lockfile"

url="https://registry.npmjs.org/@oh-my-pi/pi-coding-agent/-/pi-coding-agent-$version.tgz"
source_hash=$(nix-prefetch-url --unpack --type sha256 "$url" 2>/dev/null)
source_sri=$(nix hash convert --hash-algo sha256 --to sri "$source_hash")
npm_deps_hash=$(nix run nixpkgs#prefetch-npm-deps -- "$lockfile")

awk -v version="$version" -v source_sri="$source_sri" -v npm_deps_hash="$npm_deps_hash" '
  /^  version = / { print "  version = \"" version "\";"; next }
  /^    hash = / { print "    hash = \"" source_sri "\";"; next }
  /^  npmDepsHash = / { print "  npmDepsHash = \"" npm_deps_hash "\";"; next }
  { print }
' "$package_file" > "$package_file.tmp"
mv "$package_file.tmp" "$package_file"

echo "Updated pi-coding-agent to $version"
