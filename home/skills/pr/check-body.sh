#!/usr/bin/env bash
# Usage: check-body.sh [file] [max_words]   (reads stdin when file is "-" or omitted)
# Exit 0 when the PR body is within the limit, 1 when it is over, 2 when the draft is missing.
# Diagrams do not count: fenced mermaid/plantuml/dot/graphviz/d2 blocks and markdown images are dropped.
set -euo pipefail

file="${1:--}"
max="${2:-500}"

if [ "$file" != "-" ] && [ ! -s "$file" ]; then
  echo "FAIL: draft file '$file' is missing or empty. Write the draft first." >&2
  exit 2
fi

strip_diagrams() {
  awk '
    /^```/ {
      if (skip) { skip = 0; next }
      if ($0 ~ /^```(mermaid|plantuml|dot|graphviz|d2)/) { skip = 1; next }
    }
    skip { next }
    { gsub(/!\[[^]]*\]\([^)]*\)/, ""); print }
  '
}

count=$(if [ "$file" = "-" ]; then cat; else cat "$file"; fi | strip_diagrams | wc -w | tr -d ' ')

if [ "$count" -gt "$max" ]; then
  echo "FAIL: PR body has $count words (diagrams excluded). Limit is $max. Cut $((count - max)) words before publishing." >&2
  exit 1
fi

echo "OK: PR body has $count words (diagrams excluded). Limit is $max."
