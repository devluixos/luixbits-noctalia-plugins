#!/usr/bin/env bash
set -euo pipefail

delay="${CASIO_DECK_MOCK_DELAY:-1}"
model="generic_abcd"
invalid=false

while (($#)); do
  case "$1" in
    --model)
      model="${2:-}"
      shift 2
      ;;
    --invalid)
      invalid=true
      shift
      ;;
    *)
      printf 'error unknown mock-helper argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

emit() {
  printf '%s\n' "$1"
  sleep "$delay"
}

emit "ready mock-helper 0.1.0 $model"

if [[ "$model" == "abl100we" || "$model" == "casio_abl100we_3565" ]]; then
  emit "model casio_abl100we_3565 Casio_ABL-100WE-1A module=3565 support=experimental"
  emit "capabilities casio_abl100we_3565 lower_left,lower_right,timeplace,finder,unknown"
  emit "scan casio_abl100we_3565 CASIO_ABL-100WE-1A_MOCK 00:11:22:33:44:55 experimental"
  emit "watch casio_abl100we_3565 CASIO_ABL-100WE-1A_MOCK 00:11:22:33:44:55"
  emit "connect"
  emit "press lower_right"
  emit "press lower_left"
  emit "press timeplace"
  emit "press finder"
elif [[ "$model" == "future_casio_ble" ]]; then
  emit "model future_casio_ble Other_Casio_Bluetooth_watch module=unknown support=unsupported"
  emit "capabilities future_casio_ble"
  emit "scan future_casio_ble CASIO_UNSUPPORTED_MOCK 66:77:88:99:AA:BB unsupported"
  emit "watch future_casio_ble CASIO_UNSUPPORTED_MOCK 66:77:88:99:AA:BB"
else
  emit "model generic_abcd Generic_A_B_C_D module=none support=supported"
  emit "capabilities generic_abcd A,B,C,D"
  emit "connect"
  emit "press A"
  emit "press B"
  emit "press C"
  emit "press D"
fi

if [[ "$invalid" == true ]]; then
  emit "invalid helper line"
  emit "press Z"
  emit "error mock helper reported an error"
fi

printf '%s\n' "disconnect"
