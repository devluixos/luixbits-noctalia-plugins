# Casio Deck Helper Protocol

`casio-deck` reads normalized button events from an optional helper process.
The helper is the hardware boundary: it can talk to Bluetooth, BLE, serial,
evdev, GPIO, or another transport, but the Noctalia plugin only sees this line
protocol.

## V1 Output

```text
ready casio-deck-helper 0.1.0 casio_abl100we_3565
model casio_abl100we_3565 Casio_ABL-100WE-1A module=3565 support=experimental
capabilities casio_abl100we_3565 lower_right,finder,lower_left
scan casio_abl100we_3565 CASIO_ABL-100WE-1A 00:11:22:33:44:55 experimental
state waiting
state setup_pairing
state connecting
trace scan_start model=casio_abl100we_3565
watch casio_abl100we_3565 CASIO_ABL-100WE-1A 00:11:22:33:44:55
connect
state connected
paired casio_abl100we_3565 CASIO_ABL-100WE-1A 00:11:22:33:44:55
state pairing_complete
state subscribed
state ble_held
state session_complete
state action_complete
state action_failed
raw 26eb002d-b012-49a8-b1f8-394fb2032b0f 0102
press lower_right
state disconnected
disconnect
```

Supported lines:

- One event per line.
- Empty lines are ignored.
- `ready <helper> <version> <model>`
- `model <model> <display_name> module=<number> support=<level>`
- `capabilities <model> <comma-separated-trigger-list>`
- `scan <model> <name> <address> <support>`
- `state waiting`
- `state setup_pairing`
- `state connecting`
- `state pairing`
- `state connected`
- `state subscribed`
- `state initializing`
- `state ble_held`
- `state app_connected`
- `state session_complete`
- `state pairing_complete`
- `state action_complete`
- `state action_failed`
- `state reconnecting`
- `state disconnected`
- `state stopped`
- `state app_handshake_failed`
- `watch <model> <name> <address>`
- `paired <model> <name> <address>`
- `connect`
- `disconnect`
- `trace <message>`
- `raw <uuid-or-source> <hex-payload>`
- `press lower_right`
- `press finder`
- `press lower_left`
- `error <message>`

`raw <uuid-or-source> <hex-payload>` is allowed for fixed BLE investigation.
The bridge records it as raw diagnostic state only; it never runs an action from
raw helper payloads.

`trace <message>` is helper diagnostics intended for the UI connection log. It
must not contain shell commands and the bridge never executes it.

`press <trigger>` must use stable logical trigger names, not raw device codes.
For the current ABL-100WE action path, use `lower_right`, `finder`, or
`lower_left`. Unknown lines and unsupported triggers are ignored by the plugin
and recorded as `last_error`.

Current real ABL-100WE/module 3565 testing confirms three usable
watch-initiated session triggers: short lower right (`lower_right`), long lower
right (`finder`), and long lower left (`lower_left`). Normal short lower-left
clicks change watch modes locally and are not BLE events. `timeplace` and
`unknown` remain hardware research notes, not normal user-configurable actions.

The bridge checks triggers against the currently selected model:

- `casio_abl100we_3565`: `lower_right`, `finder`, `lower_left`

## Boundary

The helper owns:

- hardware permissions
- Bluetooth, BLE, serial, evdev, or GPIO access
- reconnects and debouncing
- raw event decoding

The Noctalia plugin owns:

- bar and shortcut state
- button press counters
- notifications
- user-configured desktop commands

Button commands are configured inside Noctalia. The plugin never executes
command text emitted by the helper.

Action mapping belongs to the plugin, not the helper. Current supported mapping
settings are per-trigger presets, per-trigger custom shell commands, and the
advanced `trigger_action_map` string:

```text
lower_right=preset:media_play_pause
finder=command:notify-send Casio Deck
```

## Local IPC Testing

Use IPC smoke commands for UI and bridge testing without hardware:

```sh
./scripts/dev/smoke-casio-deck.sh abl100we
noctalia msg plugin luixbits/casio-deck:bridge all press lower_right
noctalia msg plugin luixbits/casio-deck:bridge all error "test error"
```

## ABL-100WE Helper

The experimental helper lives in:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/helper
```

That helper is the GShockTimeServer-style Bluetooth layer for this repo. The
Noctalia plugin does not import Bluetooth libraries directly; it starts a helper
process, and the helper uses `gshock-api` plus `bleak` to connect to the watch
and emit normalized protocol lines.

Run it through the Nix-friendly wrapper:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --once --debug
```

For ABL-100WE background listener testing, configure `helper_command` to:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --listener --app-info-profile smart-sync --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --reconnect-delay 2
```

For the dashboard Pair button, configure `pair_command` to:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --setup-pairing --app-info-profile smart-sync --sync-time-on-connect --once --debug --scan-timeout 90 --connect-timeout 25 --app-init-timeout 25
```

For ABL-100WE local testing, the configured Pair command adds
`--app-info-profile smart-sync --sync-time-on-connect`. The SmartSync app-info
profile writes the newer `22 93 00 ...` scratchpad marker used by the Android
GShockAPI/SmartSync project instead of keeping the older Python `gshock-api`
`22 34 88 ...` marker. The current-time write follows the proven
GShockTimeServer transaction. Neither write is a desktop action and neither
executes helper-provided command text.

For the widget, prefer one helper process in listener mode. The process waits up
to 60 seconds for the watch to advertise, waits one second after GATT connect,
completes app-info setup, reads the detected connection initiator, emits
`press <trigger>`, emits `state session_complete`, disconnects from that short
BLE session, and returns to `state listening`/`state waiting`. This mimics the
phone-app background shape more closely than requiring a terminal command or a
manual UI session click for every action.

The ABL-100WE optional time-sync action is implemented as a minimal direct
current-time packet from Casio Deck. It intentionally avoids the broader
`gshock-api.set_time()` sequence because that path sent unsupported follow-up
commands on module 3565 during testing. In action and fixed modes this time-sync
action is not sent unless `--sync-time-on-connect` is explicitly used. Fixed
mode also avoids the home-time/world-city request `1F00` on ABL-100WE because
real hardware rejected it with `ff811f`.

Use `--session-mode action` for normal desktop action testing.
Use `--session-mode fixed` only for experimental hold-open research. Use
`--session-mode raw-probe` only for low-level Bleak notification capture.
Use `--session-mode connection-trigger` only as the legacy diagnostic fallback:
one watch-initiated connection becomes one trigger, then the helper disconnects
and waits again. Use `--session-mode poll` only for gshock-api polling research.

Useful test commands:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --scan-only --debug
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --once --debug
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --listener --app-info-profile smart-sync --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --reconnect-delay 2 --debug
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --session-mode action --app-info-profile smart-sync --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --debug
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --session-mode fixed --app-info-profile smart-sync --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --keepalive-interval 10 --debug
```

The action helper mode uses the Casio protocol layer, completes app-info setup,
emits the decoded connection initiator as a trigger, and exits the session. The
timeserver helper mode follows the same flow but writes the minimal current-time
packet before exit. The experimental fixed helper mode follows the Smart Sync
lower-left app path, emits `raw` notifications, and holds the GATT client open
until we can prove whether useful packet values map to `press <trigger>` lines.
The fallback `connection-trigger` mode uses `gshock-api`, reads the
connection-trigger value exposed by `GshockAPI.get_pressed_button()`, and emits
debounced `press <trigger>` lines.

For pairing repair, use:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --setup-pairing --repair-pairing --app-info-profile smart-sync --sync-time-on-connect --once --debug --scan-timeout 120 --connect-timeout 25 --app-init-timeout 25
```

For normal Pair/Setup, omit `--repair-pairing` so an existing Linux bond is not
removed on every click. The setup flow pairs when needed, runs the Casio
app-info handshake, writes the SmartSync scratchpad marker when needed, reads
the connection initiator without emitting a desktop action, optionally writes
the minimal current-time packet when `--sync-time-on-connect` is set, emits
`paired <model> <name> <address>`, and exits. Use `--repair-pairing` only from
the Repair path when the saved BlueZ record is stale.

The helper has a small model registry. V1 implements only
`casio_abl100we_3565`; other watches should be added as adapters with their own
scan filters, trigger vocabulary, and decoding behavior.

## Not In V1

- EDB-120 data-bank writing
- button-hold mappings
- profile or macro systems
