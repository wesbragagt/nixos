#!/usr/bin/env bash
# Records mic + speaker output while another app holds the mic, then
# transcribes it with whisper into ~/transcriptions.
set -u
# writeShellApplication adds errexit; recorder exits non-zero on SIGINT.

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/transcribe"
out_dir="$HOME/transcriptions"
disabled_flag="$state_dir/disabled"
recording_flag="$state_dir/recording"
mkdir -p "$state_dir" "$out_dir"

mic_in_use() {
  pw-dump | jq -e '[.[] | .info.props? // {}
    | select(."media.class" == "Stream/Input/Audio")
    | select(."application.name" != "transcribe")] | length > 0' >/dev/null
}

finish() {
  local base="$1"
  # Mic blips shorter than 30s are not meetings.
  local secs
  secs=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$base.mic.wav" 2>/dev/null | cut -d. -f1)
  if [ "${secs:-0}" -ge 30 ]; then
    ffmpeg -loglevel error -y -i "$base.mic.wav" -i "$base.sys.wav" \
      -filter_complex amix=inputs=2:duration=longest -ar 16000 -ac 1 "$base.wav" \
      && whisper-cli -m "$WHISPER_MODEL" -f "$base.wav" -otxt -of "$out_dir/$(basename "$base")" -np \
      && notify-send "Transcription saved" "$out_dir/$(basename "$base").txt"
  fi
  rm -f "$base".mic.wav "$base".sys.wav "$base".wav
}

daemon() {
  local base="" mic_pid="" sys_pid=""
  while true; do
    if [ -z "$base" ] && [ ! -e "$disabled_flag" ] && mic_in_use; then
      base="$state_dir/$(date +%Y-%m-%d_%H%M)"
      pw-record -P '{ application.name = "transcribe" }' "$base.mic.wav" & mic_pid=$!
      pw-record -P '{ application.name = "transcribe" stream.capture.sink = true }' "$base.sys.wav" & sys_pid=$!
      touch "$recording_flag"
      pkill -RTMIN+9 waybar || true
    elif [ -n "$base" ] && { [ -e "$disabled_flag" ] || ! mic_in_use; }; then
      kill -INT "$mic_pid" "$sys_pid"; wait "$mic_pid" "$sys_pid" || true
      rm -f "$recording_flag"
      pkill -RTMIN+9 waybar || true
      finish "$base" &
      base=""
    fi
    sleep 5
  done
}

status() {
  if [ -e "$recording_flag" ]; then
    echo '{"text":"🔴 REC","class":"recording","tooltip":"Recording meeting"}'
  elif [ -e "$disabled_flag" ]; then
    echo '{"text":"🎙 off","class":"disabled","tooltip":"Auto-transcribe off"}'
  else
    echo '{"text":"🎙","class":"enabled","tooltip":"Auto-transcribe on"}'
  fi
}

case "${1:-}" in
  daemon) rm -f "$recording_flag"; daemon ;;
  status) status ;;
  toggle)
    if [ -e "$disabled_flag" ]; then rm "$disabled_flag"; else touch "$disabled_flag"; fi
    pkill -RTMIN+9 waybar || true ;;
  *) echo "usage: transcribe daemon|status|toggle" >&2; exit 1 ;;
esac
