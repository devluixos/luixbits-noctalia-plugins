# Casio Deck ABL-100WE Connection Plan

Status: revised after real hardware testing on 2026-06-23.

## Decision

The product requirement remains button monitoring: Casio Deck should eventually
let a user assign actions to usable watch buttons and trigger them from the
watch without terminal work. The ABL-100WE/module 3565 has not yet proven that
it can stream arbitrary physical button presses while connected. Real testing
currently proves a narrower behavior: the watch can start a Bluetooth app
session, and the helper can decode the button/action that initiated that
session.

For now, ABL-100WE support is split into two tracks:

- Stable product path: background session-initiator listening. Noctalia starts
  the helper once with `--listener`; the helper stays alive, waits for
  watch-initiated Bluetooth sessions, emits one `press <trigger>` event for
  each decoded action session, disconnects that live BLE session, and returns
  to waiting.
- Research path: held/raw monitor mode. The helper keeps the BLE client open and
  records raw packets to discover whether any usable button stream exists.

The ABL-100WE should not be presented as a proven always-connected stream deck
yet. Real testing and the referenced Casio/GShockTimeServer behavior point to a
watch-initiated app transaction as the only confirmed path:

1. Noctalia autostarts the helper in listener mode.
2. User triggers a supported watch Bluetooth action.
3. Helper connects to the paired watch.
4. Helper completes Casio app-info setup.
5. Helper reads the connection initiator, currently confirmed as `lower_left`
   and `lower_right`.
6. In stable listener/action mode, helper emits the normalized trigger for
   Noctalia actions, ends the live BLE session, then waits again.
7. In experimental `fixed` mode, helper follows the Smart Sync lower-left app
   path: no time sync for `lower_left`, read Time page style values, then hold
   the GATT client open as long as the watch allows it.
8. Stable mode emits `state session_complete`, disconnects cleanly, and returns
   to `state listening`/`state waiting` while the helper process remains alive.

For this watch, `session_complete` is the success state. A permanent CNCT/search
screen is not expected in stable fallback mode. Experimental fixed/raw modes
stay available for reverse engineering full button monitoring.

## What We Have Now

- BlueZ pairing works: the watch can be `Paired`, `Bonded`, and `Trusted`.
- The helper finds the known paired address and connects when the watch
  advertises.
- The helper decodes `WatchButton.LOWER_LEFT` as `press lower_left`.
- The helper implements app-info setup locally because `gshock-api` 2.0.39
  formats the response incorrectly for its own write path. It now only writes
  the hard-coded app-info response when the watch returns the blank app-info
  challenge; if app-info is already set, it records `app_info_already_set` and
  does not write.
- The default `action` mode does not write time or watch settings.
- The optional `timeserver` mode writes Casio Deck's own minimal current-time
  packet to handle `0x0E`.
- Real hardware tests reached `state session_complete`, then clean disconnect.
- Real hardware tests confirmed `lower_left` and `lower_right`.
- The bridge can consume `ready`, `model`, `watch`, `connect`, `press`, `raw`,
  `trace`, `state`, `disconnect`, and `error`.
- The dashboard can be used to start the helper and watch connection state.

## What Changed From The Old Persistent Plan

- Removed as product default: pretending `app_connected` means the watch is
  fully usable while it still shows CNCT/search.
- Added: fixed mode now reports `ble_held` instead of `app_connected`, because
  that is the only state the helper can prove without seeing the watch display.
- Removed as product default: forcing an indefinite BLE session on ABL-100WE.
- Replaced as safe ABL fallback default: `timeserver` with `action`, because
  Casio Deck should trigger desktop actions by default and not write watch time
  unless the user explicitly asks for that. This does not replace the product
  goal of full button monitoring.
- Replaced: broad `gshock-api.set_time()` with Casio Deck's direct current-time
  packet, because the library path sent unsupported `1F00` and timed out.
- Replaced in fixed lower-left mode: unconditional time sync and broad settings
  probes. The helper now uses the ABL-safe lower-left app path with
  timer/watch-condition reads before `ble_held`.
- Removed from fixed lower-left mode: `home_time`/world-city request `1F00`,
  because real ABL-100WE hardware answered `ff811f` and the request timed out.
- Added: one-second GATT settle delay after connect, matching Smart Sync's
  browser connection path.
- Kept for research: `--session-mode fixed`, `raw-probe`, `poll`, and
  `connection-trigger`.

## Next Implementation Work

- Done: add helper `--listener` as the normal app-like background path.
- Done: make the UI language match the real flow:
  - helper running
  - waiting for watch
  - connected
  - initializing
  - session complete
  - listening again
- Done: configure local Noctalia testing to autostart the listener without
  `--max-attempts`.
- Add a separate monitor/research entry point for held/raw tests so full button
  stream work does not get confused with the safe action fallback.
- In fixed mode, complete app-info, then branch by connection initiator:
  - `lower_left`: read timer/watch-condition and hold BLE.
  - `lower_right` or no-button: write the minimal current-time packet and hold
    BLE.
  - `finder`: record/hold for capture without sending commands.
- In the Functions tab, describe ABL triggers as session initiators until a
  true held-button stream is proven.
- Done: add notification-test presets for confirmed `lower_left` and
  `lower_right`.
- Keep collecting captures for `timeplace` and `finder`.
- Only promote fixed always-connected behavior if raw captures prove the watch
  emits useful packets while the BLE client stays connected.

## Test Command

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --session-mode action --once --debug --scan-timeout 130 --connect-timeout 25 --app-init-timeout 25
./scripts/helper/run-abl100-helper.sh --model abl100we --listener --app-info-profile smart-sync --debug --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --reconnect-delay 2
```

Expected success lines:

```text
state listening
press lower_left
press lower_right
state init_complete
state session_complete
disconnect
state listening
```

## Open Questions

- Can ABL-100WE expose `timeplace` or `finder` as distinct session initiators?
- Does any mode expose button notifications after app-info setup, or does
  module 3565 firmware always cancel the session on button press?
- Which next Casio BLE model should be tested as a true always-connected watch?
