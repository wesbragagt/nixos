#!/usr/bin/env bash
# Hold-to-talk dictation: records the mic, transcribes it with Whistle,
# and types the text into the focused window.

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dictate"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dictate"
config="$config_dir/config.json"
keywords="$config_dir/keywords.txt"
history="$state_dir/history.jsonl"
pid_file="$state_dir/recording.pid"
wav="$state_dir/recording.wav"
mkdir -p "$config_dir" "$state_dir"
[ -s "$config" ] || echo '{"language":"auto","depth":"full","insert":"type","mic":"default"}' >"$config"
touch "$keywords" "$history"

get() { jq -r --arg k "$1" '.[$k]' "$config"; }

recording() { [ -s "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; }

status() {
  local mics
  mics=$(pw-dump | jq '[.[] | .info.props? // {}
    | select(."media.class" == "Audio/Source")
    | {name: ."node.name", description: (."node.description" // ."node.name")}] | unique_by(.name)')
  jq -n \
    --arg state "$(recording && echo recording || echo idle)" \
    --slurpfile config "$config" \
    --rawfile keywords "$keywords" \
    --argjson mics "$mics" \
    --slurpfile history <(tail -n 10 "$history") \
    '$config[0] + {state: $state, mics: $mics,
      keywords: ($keywords | split("\n") | map(select(length > 0))),
      history: ($history | reverse)}'
}

set_option() {
  local key="$1" value="$2"
  case "$key" in
    language) [[ "$value" =~ ^(auto|en|de|fr|es|it|nl|pl)$ ]] ;;
    depth) [[ "$value" =~ ^(full|[2-8])$ ]] ;;
    insert) [[ "$value" =~ ^(type|copy)$ ]] ;;
    mic) [ -n "$value" ] ;;
    *) false ;;
  esac || { echo "invalid $key: $value" >&2; exit 2; }
  jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$config" >"$config.tmp" && mv "$config.tmp" "$config"
}

start() {
  recording && return
  local target=()
  [ "$(get mic)" != "default" ] && target=(--target "$(get mic)")
  pw-record -P '{ application.name = "dictate" }' "${target[@]}" \
    --rate 16000 --channels 1 --format s16 "$wav" &
  echo $! >"$pid_file"
}

stop() {
  recording || return 0
  local pid args=() text
  pid=$(cat "$pid_file")
  # SIGINT lets pw-record finish the WAV header.
  kill -INT "$pid"
  while kill -0 "$pid" 2>/dev/null; do sleep 0.05; done
  rm -f "$pid_file"

  [ "$(get language)" != "auto" ] && args+=(--audio-language "$(get language)")
  [ "$(get depth)" != "full" ] && args+=(--audio-depth "$(get depth)")
  [ -s "$keywords" ] && args+=(--audio-keywords "$keywords")
  text=$(needle --model "$WHISTLE_MODEL" --audio "$wav" "${args[@]}" | jq -r '.text // ""')
  rm -f "$wav"
  [ -n "$text" ] || return 0

  if [ "$(get insert)" = "copy" ]; then
    printf '%s' "$text" | wl-copy
  else
    wtype -- "$text"
  fi
  jq -nc --arg text "$text" '{time: (now | todate), text: $text}' >>"$history"
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  set) set_option "${2:-}" "${3:-}" && status ;;
  keywords) { grep -v '^[[:space:]]*$' || true; } >"$keywords" && status ;;
  *) echo "usage: dictate start|stop|status|set <key> <value>|keywords <stdin" >&2; exit 2 ;;
esac
