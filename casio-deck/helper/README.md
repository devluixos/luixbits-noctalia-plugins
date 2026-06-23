# Casio Deck Bluetooth Helper

Experimental Linux helper for Casio Bluetooth watches. V1 implements the Casio
ABL-100WE-1A, module 3565, through a model adapter registry.

This helper is the Bluetooth side of Casio Deck. The default `action` session
connects through the Casio protocol layer, completes app-info setup, reads the
connection initiator, emits one normalized trigger for Noctalia, and
disconnects. The `--listener` option wraps that in an app-like background loop:
keep the helper alive, wait for repeated watch-initiated short sessions, handle
the action, and return to waiting. For the ABL-100WE this is more realistic than
pretending the watch can stay in a permanent app session.

The experimental hold-open path is still available through `--session-mode
fixed`. Raw notification packets are emitted as protocol `raw` lines there until
we map them to stable button triggers. The older connection-trigger diagnostic
fallback remains available through `--session-mode connection-trigger`.

The optional `timeserver` mode writes the minimal Casio current-time packet as
the accepted session action. It does not write other watch settings. Non-time
server modes only sync time when `--sync-time-on-connect` is explicitly used.

## Run

From the repository root:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --once --debug
```

Use listener mode from Noctalia once pairing/setup is done:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --listener --app-info-profile smart-sync --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --reconnect-delay 2 --debug
```

The helper should sit in `state listening`/`state waiting`, process a confirmed
lower-right or lower-left watch-initiated session, emit `press <trigger>`, then
return to listening. For held-connection research, use fixed mode explicitly
with a larger scan window:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --session-mode fixed --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --keepalive-interval 10 --debug
```

In fixed mode, success is `state ble_held`. That means Linux still has the BLE
GATT client open after app-info setup. For confirmed `lower_left`, fixed mode
skips time sync, reads ABL-safe status values, and then holds the link. It does
not prove that the watch display has left the connection screen.

Run the explicit Pair/Setup flow from the helper:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --setup-pairing --sync-time-on-connect --once --debug --scan-timeout 90 --connect-timeout 25 --app-init-timeout 25
```

For normal Pair/Setup, omit `--repair-pairing`. The setup flow uses the saved
Linux bond when available, completes the Casio app-info handshake, reads the
connection initiator without emitting a desktop action, optionally writes the
minimal current-time packet when `--sync-time-on-connect` is set, emits
`paired ...`, and exits. Use `--repair-pairing` only when the saved Linux record
is stale.

Scan only:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --scan-only --debug
```

Connect once in default action mode and exit after the transaction:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --once --debug
```

Run action mode as an explicit one-shot UI test:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --session-mode action --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --debug
```

Experimental hold-open mode:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --once --session-mode fixed --debug
```

Legacy connection-trigger diagnostic mode:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --loop --session-mode connection-trigger --debug
```

Low-level Bleak-only raw notification probe:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --loop --session-mode raw-probe --debug
```

Experimental gshock-api polling mode for future/watch-specific research:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --loop --session-mode poll --debug
```

Optional time sync for non-time-server research modes:

```sh
./scripts/helper/run-abl100-helper.sh --model abl100we --loop --sync-time-on-connect --debug
```

## Watch Test

Keep the phone app/Bluetooth disconnected while testing with the PC.

Recommended capture runner:

```sh
./scripts/dev/capture-abl100-session.sh --seconds 180
```

It writes:

- `captures/abl100we-*/helper.stdout.log`
- `captures/abl100we-*/helper.stderr.log`
- `captures/abl100we-*/btmon.cfa` when `btmon` is available
- `captures/abl100we-*/session-summary.txt`

1. Start `btmon` capture:

   ```sh
   sudo btmon -w "abl100we-$(date +%Y%m%d-%H%M%S).cfa"
   ```

2. Run the helper in action transaction mode:

   ```sh
   ./scripts/helper/run-abl100-helper.sh --model abl100we --session-mode action --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --debug
   ```

3. Try watch actions:

   - Put the watch into its Bluetooth connection mode once.
   - Wait for the widget/helper to show `session_complete`.
   - The watch should leave CNCT/search mode after the transaction ends.
   - If the watch drops the link before completion, the helper returns to waiting/reconnecting.

Use `--session-mode fixed` only when researching whether the watch can hold the
link. If fixed mode cannot hold the link, run `--session-mode
connection-trigger --debug` as a fallback capture. Do not press
extra buttons while the watch is still searching/connecting in that fallback
mode; on the ABL-100WE that cancels the connection flow instead of producing
another event.

The app-info handshake is implemented in this helper instead of through
`gshock-api.get_app_info()` because `gshock-api` 2.0.39 formats its app-info
response in a form its own write path does not accept. Casio Deck matches Smart
Sync here: it sends compact response `223488F4E5D5AFC829E06D02` only if the
watch returns blank app-info challenge `22FFFFFFFFFFFFFFFFFFFF00`. If the watch
already returns `223488F4E5D5AFC829E06D02`, the helper records
`app_info_already_set` and does not write.

In default action mode, Casio Deck emits the decoded connection initiator as a
Noctalia trigger and does not write watch settings. `session_complete` is the
stable success state. Optional time-server mode writes only the minimal
current-time packet. This avoids the broader `gshock-api.set_time()` path that
sends unsupported follow-up commands on ABL-100WE. In fixed lower-left mode,
the expected action is no time sync; it probes timer and watch condition, then
emits `ble_held`. The
home-time/world-city request is intentionally skipped on ABL-100WE because real
hardware rejected `1F00` with `ff811f`.

Expected stdout lines look like:

```text
ready casio-deck-helper 0.1.0 casio_abl100we_3565
model casio_abl100we_3565 Casio_ABL-100WE-1A module=3565 support=experimental
capabilities casio_abl100we_3565 lower_left,lower_right,finder
state waiting
state connecting
connect
watch casio_abl100we_3565 CASIO_ABL-100WE-1A XX:XX:XX:XX:XX:XX
state connected
state initializing
press lower_left
state init_complete
state phone_probe
trace phone_probe timer request
trace phone_probe watch_condition request
trace hold_action skip_sync_before_hold button=lower_left
state ble_held
raw 26eb002d-b012-49a8-b1f8-394fb2032b0f 0102
```

## Adapter Registry

The helper-side registry lives in:

```text
src/casio_deck_helper/models.py
```

An adapter defines:

- model id
- aliases accepted by `--model`
- display name and module number
- scan filters
- normalized trigger ids
- capabilities and support level

Only `casio_abl100we_3565` is implemented. Future watches should be added as
new adapters instead of adding Bluetooth logic to the Noctalia Luau plugin.

To add another watch:

1. Create `src/casio_deck_helper/adapters/<watch>/`.
2. Add `<watch>/model.py` with a `MODEL = CasioModelAdapter(...)`.
3. Add `<watch>/runtime.py` with an adapter class exposing `scan_only`,
   `setup_pairing`, and `run_connected_session`.
4. Register the model in `src/casio_deck_helper/models.py`.
5. Dispatch the runtime in `src/casio_deck_helper/runtime.py`.
6. Add matching UI metadata in `casio-deck/data/models.deck`.

## Code Structure

```text
src/casio_deck_helper/
  cli.py                 CLI args and reconnect/listener loop
  runtime.py             Model id to runtime adapter dispatch
  models.py              Supported watch model registry
  model_types.py         Shared model adapter dataclass
  protocol.py            Normalized stdout protocol helpers
  bluez.py               BlueZ bluetoothctl pairing/trust helpers
  debounce.py            Duplicate trigger suppression
  adapters/
    abl100/
      model.py           ABL-100WE model metadata and aliases
      runtime.py         ABL-100WE session flows
      connection.py      BLE/GShock scanning, connect, notify, disconnect
      app_info.py        Casio app-info scratchpad profile policy
      triggers.py        Button enum to normalized trigger mapping
      time_sync.py       Minimal current-time packet helpers
```

## Extension Points

Watch-specific Bluetooth code belongs under `adapters/<watch>/`. The root
helper package should stay watch-agnostic: CLI, registry, protocol, BlueZ
helpers, debounce, and runtime dispatch.

Noctalia-visible model metadata belongs in `casio-deck/data/models.deck`.
Noctalia action presets and trigger labels belong in
`casio-deck/data/actions.deck`. If a new action is just a desktop command, add
it there. If a new action needs plugin-owned state changes, add a named
`special` preset there and implement the hook in
`casio-deck/entries/service/bridge.luau`.
