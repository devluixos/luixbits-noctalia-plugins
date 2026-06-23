#!/usr/bin/env bash
set -euo pipefail

noctalia="${NOCTALIA_BIN:-noctalia}"
plugin_id="${CASIO_DECK_PLUGIN_ID:-luixbits/casio-deck}"
target="${NOCTALIA_PLUGIN_TARGET:-all}"
model="${1:-${CASIO_DECK_SMOKE_MODEL:-abl100we}}"
run_actions="${CASIO_DECK_SMOKE_RUN_ACTIONS:-0}"

run() {
  printf '+ %q msg plugin %q:bridge %q %q' "$noctalia" "$plugin_id" "$target" "$1"
  if [[ $# -gt 1 ]]; then
    printf ' %q' "$2"
  fi
  printf '\n'
  "$noctalia" msg plugin "$plugin_id:bridge" "$target" "$@"
}

case "$model" in
  abl|abl100|abl100we|casio_abl100we_3565)
    run select_model casio_abl100we_3565
    run status
    if [[ "$run_actions" == "1" ]]; then
      run start_helper
      run press lower_left
      run press lower_right
    fi
    ;;
  *)
    printf 'unknown smoke model: %s\n' "$model" >&2
    printf 'usage: %s [abl100we]\n' "$0" >&2
    exit 2
    ;;
esac
