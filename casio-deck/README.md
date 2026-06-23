# Casio Deck

Noctalia v5 plugin foundation for using a Casio watch as a stream-deck-like
controller.

V1 focuses on the Casio ABL-100WE-1A / module 3565, but the structure is
model-adapter based so other Casio Bluetooth watches can be added later without
changing the Noctalia action layer.

The plugin provides the bar widget, bridge service, control-center shortcut,
temporary desktop setup widget, experimental Python Bluetooth helper, model
capabilities, presets, and custom trigger commands.

## Layout

```text
/home/luiz/projects/noctalia-plugins/
  catalog.toml
  casio-deck/
    plugin.toml
    dashboard.luau
    entries/
      README.md
      service/bridge.luau
      widgets/status.luau
      shortcuts/shortcut.luau
    data/
      models.deck
      actions.deck
    helper/
      src/casio_deck_helper/
        adapters/abl100/
    translations/en.json
```

The Noctalia path source must point at the parent source root:

```text
/home/luiz/projects/noctalia-plugins
```

The plugin id `luixbits/casio-deck` maps to the `casio-deck` directory.
The old QML prototype is archived in `../archive/casio-deck-qml/` and is not
part of the portable v5 plugin.

Active UI/backend locations:

- Bar UI: `entries/widgets/status.luau`
- Temporary tabbed setup UI: `dashboard.luau`
- Bridge service/state/actions: `entries/service/bridge.luau`
- Control-center shortcut: `entries/shortcuts/shortcut.luau`
- Shared watch/action metadata: `data/models.deck`, `data/actions.deck`
- Bluetooth helper package: `helper/src/casio_deck_helper/`

`dashboard.luau` intentionally stays at the plugin root. Current Noctalia v5
desktop widgets are loaded/watched from that root entry path even though the
other plugin entries can live cleanly under `entries/`.

## Where To Extend

Add a new Casio watch in three places:

- Helper Bluetooth adapter:
  `helper/src/casio_deck_helper/adapters/<watch>/`
- Helper registry/dispatch:
  `helper/src/casio_deck_helper/models.py` and
  `helper/src/casio_deck_helper/runtime.py`
- Plugin-visible model data:
  `data/models.deck`

Add a new desktop action in two places:

- Preset command/label metadata: `data/actions.deck`
- Manifest setting/translations only if the action needs a new configurable
  command field: `plugin.toml` and `translations/en.json`

Most actions should be shell-command presets in `data/actions.deck`. The bridge
executes only configured presets or configured shell command strings; helpers
never send commands.

## Local Noctalia Config

For a normal local Noctalia setup, add a path source and enable the plugin:

```toml
[plugins]
enabled = ["luixbits/casio-deck"]

[[plugins.source]]
name = "local-dev"
kind = "path"
location = "/home/luiz/projects/noctalia-plugins"
auto_update = false
```

Then add a widget instance and place it on the bar:

```toml
[widget.casio_deck]
type = "luixbits/casio-deck:status"
label = "Casio"
show_label = true
show_press_count = true
hide_disconnected = false

[bar.default]
start = ["launcher", "casio_deck", "wallpaper"]
```

The bar widget is the main UI surface for now. Left-click is reserved for the
future dropdown panel and currently reports that Noctalia v5 does not expose
plugin-owned bar panels yet. Right-click reports bridge status, and middle-click
sends a quick test trigger for the selected model.

In this NixOS/Home Manager setup, the same wiring lives in
`home/modules/niri/noctalia/default.nix`.

Plugin-level settings such as `watch_model`, `pair_command`, `helper_command`,
and command mappings are edited from Settings -> Plugins -> Casio Deck -> gear.
For normal ABL-100WE use, enable `autostart_helper` and run the helper in
listener mode. The helper then stays alive in the background and waits for
watch-initiated short action sessions.

For ABL-100WE background listener testing, set `helper_command` to:

```text
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --listener --app-info-profile smart-sync --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --reconnect-delay 2
```

In this mode the helper is expected to sit in `listening` or `waiting`, handle a
short watch-initiated session, emit the decoded trigger to Noctalia, disconnect
from that live BLE session, and return to listening. That is different from
losing the saved BlueZ bond.

For the Connection tab Pair button, set `pair_command` to:

```text
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --setup-pairing --sync-time-on-connect --once --debug --scan-timeout 90 --connect-timeout 25 --app-init-timeout 25
```

Use Pair first when setting up the watch. In normal local config Pair does not
remove the existing Linux bond; Repair is the destructive remove-and-pair path.
Pair also writes the minimal current-time packet because the proven
GShockTimeServer transaction does that before disconnecting. After Pair
succeeds, use Listener mode and trigger the watch from Timekeeping mode with
short lower right, long lower right, or long lower left.

On ABL-100WE/module 3565, Casio Deck currently cannot see every normal physical
button click. The confirmed usable session triggers are short lower right,
long lower right, and long lower left. Short lower-left
changes watch mode locally and does not start a BLE action session. Full
four-button behavior would require a different watch protocol path, a different
watch model, or more reverse engineering.

## Test Commands

After Noctalia has loaded the plugin, simulate events:

```sh
./scripts/dev/smoke-casio-deck.sh abl100we
```

The smoke script only dispatches safe model/status IPC by default. Real press
actions can run configured desktop commands, so opt in when you want that:

```sh
CASIO_DECK_SMOKE_RUN_ACTIONS=1 ./scripts/dev/smoke-casio-deck.sh abl100we
```

Equivalent ABL smoke commands:

```sh
noctalia msg plugin luixbits/casio-deck:bridge all select_model casio_abl100we_3565
noctalia msg plugin luixbits/casio-deck:bridge all start_helper
noctalia msg plugin luixbits/casio-deck:bridge all press lower_left
noctalia msg plugin luixbits/casio-deck:bridge all press lower_right
noctalia msg plugin luixbits/casio-deck:bridge all status
```

You can also target the bar widget when it is placed:

```sh
noctalia msg plugin luixbits/casio-deck:status focused press lower_right
```

## Button Actions

Each trigger can use a preset or one configured shell command:

- `lower_right_preset`
- `lower_right_command`
- `finder_preset`
- `finder_command`
- `lower_left_preset`
- `lower_left_command`

Presets include:

- `notification_test`
- `media_play_pause`
- `volume_up`
- `volume_down`
- `audio_mute_toggle`
- `mic_mute_toggle`
- `screenshot_region`
- `clipboard`
- `launcher`
- `lock`
- `teams_accept_audio`
- `teams_accept_video`
- `teams_toggle_mute`
- `teams_decline_call`
- `teams_leave_call`

The Teams presets send Microsoft Teams keyboard shortcuts through `wtype` on
Wayland. They depend on Teams or its call UI accepting those shortcuts.

The Functions tab can also change presets directly. The current Luau desktop
widget API exposes buttons but no dropdown/select control, so Casio Deck uses
compact previous/next action selector buttons. Widget-selected mappings are
persisted in `~/.cache/casio-deck/action-map.txt` and override plugin settings.

Empty commands are valid. They record the button press, update the bar, and run
nothing. A harmless test value for any command setting is `true`.

Advanced mappings can be placed in `trigger_action_map`:

```text
lower_right=preset:media_play_pause
finder=command:notify-send Casio Deck
```

## UI Surfaces

Casio Deck currently uses the supported Noctalia v5 plugin surfaces:

- `status`: compact bar widget with glyph, label, tooltip, IPC handling, and
  click actions for status and bridge forwarding.
- `toggle`: control-center shortcut for quick listener actions.
- `dashboard`: temporary four-tab desktop widget for Overview, Connection,
  Functions, and About.
- Settings gear: command text editing under Settings -> Plugins -> Casio Deck.

Native Clipboard/System-style plugin panels are not available from the current
Noctalia v5 Luau plugin API. This is the reason the active v5 bar widget cannot
open a tabbed dropdown on left click. When Noctalia exposes a plugin panel
surface, the same tab structure should move from the desktop widget into the
bar-click dropdown. The archived QML prototype is local research only; it is
not the shareable v5 plugin path.

## Desktop Test Dashboard

Until v5 plugin panels exist, use the desktop widget dashboard to test the
actual bridge behavior with a visible UI.

Tabs:

- Overview: connection state, helper state, last trigger/action, errors, press
  count, and quick actions.
- Connection: model selection, helper controls, pair/setup state, listener
  state, and the current saved watch/device.
- Functions: model-specific trigger list, active mappings, and trigger test
  buttons.
- About: plugin purpose, hardware support, LuixBits channel URL, and future
  explanation video URL.

Local test config:

```toml
[desktop_widgets]
enabled = true
schema_version = 2
widget_order = [ "casio_deck_dashboard" ]

[desktop_widgets.widget.casio_deck_dashboard]
type = "luixbits/casio-deck:dashboard"
output = "DP-1"
cx = 540.0
cy = 360.0
box_width = 0.0
box_height = 0.0
rotation = 0.0
```

Useful commands:

```sh
noctalia msg desktop-widgets-show
noctalia msg desktop-widgets-edit
noctalia msg plugin luixbits/casio-deck:dashboard all press lower_right
```

Current Noctalia may warn during `noctalia config validate` that plugin desktop
widget types are unrecognized. Runtime still resolves the full
`author/plugin:entry` type after plugin loading.

## Helper Stream

The bridge can run an external helper with `helper_command`. The helper prints
one normalized event per line:

```text
ready casio-deck-helper 0.1.0 casio_abl100we_3565
model casio_abl100we_3565 Casio_ABL-100WE-1A module=3565 support=experimental
capabilities casio_abl100we_3565 lower_right,finder,lower_left
watch casio_abl100we_3565 CASIO_ABL-100WE-1A XX:XX:XX:XX:XX:XX
state connecting
state pairing
connect
state connected
state subscribed
raw 26eb002d-b012-49a8-b1f8-394fb2032b0f 0102
press lower_right
state reconnecting
error optional message
state disconnected
disconnect
```

For local testing without hardware, use IPC smoke commands:

```sh
./scripts/dev/smoke-casio-deck.sh abl100we
noctalia msg plugin luixbits/casio-deck:bridge all press lower_right
noctalia msg plugin luixbits/casio-deck:bridge all error "test error"
```

## ABL-100WE Connection Test

The experimental helper is where the Bluetooth work lives. Default mode now
targets a GShockTimeServer-style transaction: the helper connects through the
Casio protocol layer, reads the connection initiator, runs one action such as
time sync, emits `state session_complete`, and disconnects.

For ABL-100WE, Casio Deck now performs the time-sync action with its own minimal
current-time packet instead of `gshock-api.set_time()`. The broader library call
sent an unsupported `1F00` command on this watch, which caused the watch to
answer `ff811f` and the session to time out.

The experimental hold-open path is available with `--session-mode fixed`. It
emits raw BLE notifications while the watch allows the link. The older
connection-trigger fallback is still available with `--session-mode
connection-trigger`.

Before testing with the watch, keep phone Bluetooth or the CASIO WATCHES app off
so the watch does not connect to the phone instead of the PC.

Start a Bluetooth capture:

```sh
sudo btmon -w "abl100we-$(date +%Y%m%d-%H%M%S).cfa"
```

Or run the bundled capture session script, which records helper stdout/stderr
and starts `btmon` when available:

```sh
/home/luiz/projects/noctalia-plugins/scripts/dev/capture-abl100-session.sh --seconds 180
```

Run the helper manually when you do not need a full capture bundle:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --session-mode action --once --debug
```

Use experimental fixed mode only when investigating whether the watch can hold a
full app-session link:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --session-mode fixed --once --debug
```

Use the low-level raw probe only when investigating Bleak notifications without
the Casio app-session handshake:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --loop --session-mode raw-probe --debug
```

Use the legacy connection-trigger fallback only when investigating the short
watch-initiated session:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --loop --session-mode connection-trigger --debug
```

Use experimental gshock-api polling only when investigating BLE behavior:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --loop --session-mode poll --debug
```

Then try the watch operations in action mode:

- Put the watch into Bluetooth connection/search mode once.
- Wait for the widget/helper state to become `listening` or `waiting`.
- Press the confirmed watch action trigger. A successful action session should
  briefly show `connected`/`init_complete`/`session_complete` and then return to
  listening.
- Treat `session_complete` as one completed short action transaction. A
  permanent CNCT screen is not required for the listener workflow.
- If the watch drops the link before completion, the helper should go back to
  waiting/reconnecting without terminal work.

If you switch to `--session-mode connection-trigger`, do not press extra buttons
while the watch is still searching/connecting; on ABL-100WE this cancels the
Bluetooth flow rather than sending another event.

After a capture run, inspect:

- `captures/abl100we-*/helper.stdout.log` for protocol lines like `watch`,
  `state`, and `press`.
- `captures/abl100we-*/helper.stdout.log` for `raw` BLE notification lines.
- `captures/abl100we-*/helper.stderr.log` for raw library diagnostics.
- `captures/abl100we-*/btmon.cfa` for BLE traffic when `btmon` was available.
- `captures/abl100we-*/session-summary.txt` for a compact summary.

If the helper works and you want to test a held session, set `watch_model` to
`casio_abl100we_3565` and `helper_command` to:

```text
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --session-mode fixed --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --keepalive-interval 10
```

The helper owns hardware-specific Bluetooth, BLE, serial, evdev, GPIO,
reconnect, and debounce logic. The plugin owns Noctalia state, UI,
notifications, and user-configured button actions.
