# Casio Deck Helper Protocol

`casio-deck` reads normalized button events from an optional helper process.
The helper is the hardware boundary: it can talk to Bluetooth, BLE, serial,
evdev, GPIO, or another transport, but the Noctalia plugin only sees this line
protocol.

## V1 Output

```text
ready casio-deck-helper 0.1.0 casio_abl100we_3565
model casio_abl100we_3565 Casio_ABL-100WE-1A module=3565 support=experimental
capabilities casio_abl100we_3565 lower_left,lower_right,timeplace,finder,unknown
scan casio_abl100we_3565 CASIO_ABL-100WE-1A 00:11:22:33:44:55 experimental
watch casio_abl100we_3565 CASIO_ABL-100WE-1A 00:11:22:33:44:55
connect
press lower_right
disconnect
```

Supported lines:

- One event per line.
- Empty lines are ignored.
- `ready <helper> <version> <model>`
- `model <model> <display_name> module=<number> support=<level>`
- `capabilities <model> <comma-separated-trigger-list>`
- `scan <model> <name> <address> <support>`
- `watch <model> <name> <address>`
- `connect`
- `disconnect`
- `press A`
- `press B`
- `press C`
- `press D`
- `press lower_left`
- `press lower_right`
- `press timeplace`
- `press finder`
- `press unknown`
- `error <message>`

`press <trigger>` must use stable logical trigger names, not raw device codes.
For generic helpers, `A` through `D` are still supported. For the ABL-100WE
test helper, use `lower_left`, `lower_right`, `timeplace`, `finder`, or
`unknown`. Unknown lines and unsupported triggers are ignored by the plugin and
recorded as `last_error`.

The bridge checks triggers against the currently selected model:

- `generic_abcd`: `A`, `B`, `C`, `D`
- `casio_abl100we_3565`: `lower_left`, `lower_right`, `timeplace`, `finder`,
  `unknown`
- `future_casio_ble`: no accepted triggers until an adapter is implemented

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

## Local Mock Helper

For local testing without hardware:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh
```

Use this as the plugin `helper_command`:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh
```

To test invalid-line handling:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --invalid
```

To test ABL-100WE-style events without a watch:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --model abl100we
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
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --loop --debug
```

For the dashboard Scan button, configure `scan_command` to:

```sh
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --scan-only --debug
```

For continuous watch-trigger listening, configure `helper_command` to:

```sh
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --loop
```

Useful test commands:

```sh
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --scan-only --debug
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --once --debug
```

The helper uses `gshock-api` and `bleak`, reads the watch-trigger value exposed
by `GshockAPI.get_pressed_button()`, emits one `press <trigger>` line, and then
disconnects. It does not set time or write watch settings.

The helper has a small model registry. V1 implements only
`casio_abl100we_3565`; other watches should be added as adapters with their own
scan filters, trigger vocabulary, and decoding behavior.

## Not In V1

- EDB-120 data-bank writing
- button-hold mappings
- profile or macro systems
