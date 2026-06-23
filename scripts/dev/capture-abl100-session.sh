#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper="$repo_root/scripts/helper/run-abl100-helper.sh"
timestamp="$(date +%Y%m%d-%H%M%S)"
out_dir="${CASIO_DECK_CAPTURE_DIR:-$repo_root/captures/abl100we-$timestamp}"
duration="${CASIO_DECK_CAPTURE_SECONDS:-120}"
with_btmon=1
helper_args=()
btmon_pid=""

usage() {
  cat <<EOF
usage: $0 [options] [-- helper args...]

Options:
  --seconds N      Run helper for N seconds. Default: $duration
  --out-dir DIR    Capture directory. Default: $out_dir
  --no-btmon       Do not start btmon capture.
  --address ADDR   Pass a BLE address to the helper.
  -h, --help       Show this help.

Examples:
  $0 --seconds 180
  $0 --no-btmon -- --poll-interval 1 --debug
  $0 --seconds 180 -- --session-mode connection-trigger --debug
  $0 --address FC:51:1B:85:68:53
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seconds)
      duration="${2:?missing value for --seconds}"
      shift 2
      ;;
    --out-dir)
      out_dir="${2:?missing value for --out-dir}"
      shift 2
      ;;
    --no-btmon)
      with_btmon=0
      shift
      ;;
    --address)
      helper_args+=(--address "${2:?missing value for --address}")
      shift 2
      ;;
    --)
      shift
      helper_args+=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cleanup() {
  if [[ -n "$btmon_pid" ]]; then
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      kill "$btmon_pid" >/dev/null 2>&1 || true
    else
      sudo kill "$btmon_pid" >/dev/null 2>&1 || kill "$btmon_pid" >/dev/null 2>&1 || true
    fi
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$out_dir"

stdout_log="$out_dir/helper.stdout.log"
stderr_log="$out_dir/helper.stderr.log"
summary_log="$out_dir/session-summary.txt"
btmon_capture="$out_dir/btmon.cfa"

start_btmon() {
  if [[ "$with_btmon" -eq 0 ]]; then
    printf 'btmon: skipped by --no-btmon\n' | tee -a "$summary_log"
    return
  fi

  if ! command -v btmon >/dev/null 2>&1; then
    printf 'btmon: command not found; install bluez or run inside nix shell nixpkgs#bluez\n' | tee -a "$summary_log"
    return
  fi

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if ! sudo -v; then
      printf 'btmon: sudo auth failed; continuing without btmon capture\n' | tee -a "$summary_log"
      return
    fi
    sudo btmon -w "$btmon_capture" >/dev/null 2>"$out_dir/btmon.stderr.log" &
  else
    btmon -w "$btmon_capture" >/dev/null 2>"$out_dir/btmon.stderr.log" &
  fi

  btmon_pid="$!"
  printf 'btmon: writing %s\n' "$btmon_capture" | tee -a "$summary_log"
}

cat >"$summary_log" <<EOF
Casio Deck ABL-100WE capture
started: $(date --iso-8601=seconds)
duration_seconds: $duration
out_dir: $out_dir
helper: $helper --model abl100we --loop --debug ${helper_args[*]}

Watch actions to try:
1. Keep phone Bluetooth/CASIO WATCHES app disconnected.
2. Put the watch into Bluetooth connection/search mode once.
3. Wait for state connected/subscribed.
4. Press candidate buttons and watch for raw protocol lines.
5. If fixed mode cannot hold the link, rerun with --session-mode connection-trigger.
EOF

start_btmon

printf 'capture directory: %s\n' "$out_dir"
printf 'helper stdout:    %s\n' "$stdout_log"
printf 'helper stderr:    %s\n' "$stderr_log"
printf 'duration:         %s seconds\n\n' "$duration"
printf 'Now put the watch in Bluetooth connection mode and watch for connected/subscribed/raw lines.\n\n'

set +e
timeout --foreground "$duration" \
  "$helper" --model abl100we --loop --debug "${helper_args[@]}" \
  > >(tee "$stdout_log") \
  2> >(tee "$stderr_log" >&2)
status="$?"
set -e

{
  printf '\nfinished: %s\n' "$(date --iso-8601=seconds)"
  printf 'helper_exit_status: %s\n' "$status"
  printf '\nlast protocol lines:\n'
  grep -E '^(ready|model|capabilities|scan|state|watch|connect|disconnect|press|raw|error)([[:space:]]|$)' "$stdout_log" | tail -n 80 || true
} >>"$summary_log"

printf '\nCapture finished.\n'
printf 'Summary: %s\n' "$summary_log"
printf 'Protocol lines:\n'
grep -E '^(ready|model|capabilities|scan|state|watch|connect|disconnect|press|raw|error)([[:space:]]|$)' "$stdout_log" | tail -n 40 || true

if [[ "$status" -eq 124 ]]; then
  printf '\nHelper stopped after timeout. That is expected for capture sessions.\n'
  exit 0
fi

exit "$status"
