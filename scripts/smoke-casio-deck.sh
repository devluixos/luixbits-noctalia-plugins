#!/usr/bin/env bash
set -euo pipefail

noctalia="${NOCTALIA_BIN:-noctalia}"
plugin_id="${CASIO_DECK_PLUGIN_ID:-luixbits/casio-deck}"
target="${NOCTALIA_PLUGIN_TARGET:-all}"

run() {
  printf '+ %q msg plugin %q:bridge %q %q' "$noctalia" "$plugin_id" "$target" "$1"
  if [[ $# -gt 1 ]]; then
    printf ' %q' "$2"
  fi
  printf '\n'
  "$noctalia" msg plugin "$plugin_id:bridge" "$target" "$@"
}

run connect
run press A
run press B
run status
run disconnect
