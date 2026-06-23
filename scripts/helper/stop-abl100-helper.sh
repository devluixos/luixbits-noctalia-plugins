#!/usr/bin/env bash
set -euo pipefail

pattern="${CASIO_DECK_HELPER_STOP_PATTERN:-casio_deck_helper.cli.*--listener}"
pids=()

while IFS= read -r pid; do
  case "$pid" in
    "" | "$$" | "$PPID") continue ;;
  esac
  pids+=("$pid")
done < <(pgrep -f "$pattern" || true)

if [ "${#pids[@]}" -eq 0 ]; then
  printf 'state stopped\n'
  exit 0
fi

for pid in "${pids[@]}"; do
  kill -TERM "$pid" 2>/dev/null || true
done

sleep 0.5

for pid in "${pids[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
done

printf 'state stopped\n'
