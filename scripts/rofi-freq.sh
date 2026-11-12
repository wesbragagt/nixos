#!/usr/bin/env bash
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-freq.tsv"
mkdir -p "$(dirname "$CACHE")"
[ -f "$CACHE" ] || : > "$CACHE"

dirs=("$HOME/.local/share/applications")

if [ -n "${XDG_DATA_DIRS:-}" ]; then
  IFS=':' read -ra data_dirs <<< "$XDG_DATA_DIRS"
  for dir in "${data_dirs[@]}"; do
    [ -d "$dir/applications" ] && dirs+=("$dir/applications")
  done
fi

# Collect all .desktop file paths (dedup by basename, first-seen wins).
mapfile -t files < <(
  for dir in "${dirs[@]}"; do
    [ -d "$dir" ] && find "$dir" -maxdepth 1 \( -type f -o -type l \) -name '*.desktop'
  done | awk '!seen[gensub(/.*\//,"",1,$0)]++'
)

[ ${#files[@]} -eq 0 ] && exit 0

# One awk pass over all files: emit "id\tname\ticon" for visible Applications.
# Then merge with cache counts and sort.
choice=$({ awk -F= '
  FNR==1 { in_de=0; type=""; name=""; icon=""; nodisp=0; hidden=0;
           split(FILENAME, a, "/"); id=a[length(a)] }
  /^\[Desktop Entry\][[:space:]]*$/ { in_de=1; next }
  /^\[/ && in_de {
    if (type=="Application" && !nodisp && !hidden && name!="") {
      gsub(/\t/," ", name); gsub(/\t/," ", icon)
      print id "\t" name "\t" (icon==""?"applications-other":icon)
    }
    in_de=0
  }
  in_de && /^Type=/        { type=substr($0,6) }
  in_de && /^Name=/ && name=="" { name=substr($0,6) }
  in_de && /^Icon=/ && icon=="" { icon=substr($0,6) }
  in_de && /^NoDisplay=true/ { nodisp=1 }
  in_de && /^Hidden=true/    { hidden=1 }
  ENDFILE {
    if (in_de && type=="Application" && !nodisp && !hidden && name!="") {
      gsub(/\t/," ", name); gsub(/\t/," ", icon)
      print id "\t" name "\t" (icon==""?"applications-other":icon)
    }
  }
' "${files[@]}"
  chromium-profile --list | awk -F'\t' '{ gsub(/[\t\r\n]/, " ", $2); print "chromium-profile:" $1 "\tChromium - " $2 "\tchromium" }'
} | awk -F'\t' -v cache="$CACHE" -v ESC=$'\x1f' '
  BEGIN {
    while ((getline line < cache) > 0) {
      n = split(line, p, "\t")
      if (n>=2) counts[p[2]] = p[1]
    }
    close(cache)
  }
  { printf "%d\t%s\t%s\t%s\n", (counts[$1]?counts[$1]:0), $1, $2, $3 }
' | sort -t$'\t' -k1,1nr -k3,3 \
  | awk -F'\t' -v ESC=$'\x1f' '{ printf "%s\tApplication\t%s\0icon%s%s\n", $3, $2, ESC, $4 }' \
  | rofi -dmenu -i -p "Apps" -display-column-separator $'\t' -display-columns 1,2 -format s)

[ -z "$choice" ] && exit 0
sel_id=$(printf '%s' "$choice" | cut -f3)
[ -z "$sel_id" ] && exit 0

# Update cache: bump selected, rewrite atomically.
awk -F'\t' -v id="$sel_id" '
  BEGIN { bumped=0 }
  $2==id { print ($1+1) "\t" id; bumped=1; next }
  { print }
  END { if (!bumped) print "1\t" id }
' "$CACHE" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"

if [[ "$sel_id" == chromium-profile:* ]]; then
  chromium-profile "${sel_id#chromium-profile:}" >/dev/null 2>&1 &
else
  gtk-launch "${sel_id%.desktop}" >/dev/null 2>&1 &
fi
disown
