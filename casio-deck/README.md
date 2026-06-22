# Casio Deck

Noctalia v5 plugin foundation for using a Casio watch as a stream-deck-like
controller.

V1 focuses on the Casio ABL-100WE-1A / module 3565, but the structure is
model-adapter based so other Casio Bluetooth watches can be added later without
changing the Noctalia action layer.

The plugin provides the bar widget, bridge service, control-center shortcut,
temporary desktop setup widget, mock helper, experimental Python Bluetooth
helper, model capabilities, presets, and custom trigger commands.

## Layout

```text
/home/luiz/projects/noctalia-plugins/
  catalog.toml
  casio-deck/
    plugin.toml
    bridge.luau
    helper/
    examples/mock-helper.sh
    qml/
    dashboard.luau
    status.luau
    shortcut.luau
    translations/en.json
    assets/
```

The Noctalia path source must point at the parent source root:

```text
/home/luiz/projects/noctalia-plugins
```

The plugin id `luixbits/casio-deck` maps to the `casio-deck` directory.

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

Plugin-level settings such as `watch_model`, `helper_command`, and command
mappings are edited from Settings -> Plugins -> Casio Deck -> gear.

For the ABL-100WE local scan button, set `scan_command` to:

```text
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --scan-only --debug
```

For continuous watch-trigger listening, set `helper_command` to:

```text
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --loop
```

## Test Commands

After Noctalia has loaded the plugin, simulate events:

```sh
noctalia msg plugin luixbits/casio-deck:bridge all connect
noctalia msg plugin luixbits/casio-deck:bridge all press A
noctalia msg plugin luixbits/casio-deck:bridge all press B
noctalia msg plugin luixbits/casio-deck:bridge all status
noctalia msg plugin luixbits/casio-deck:bridge all disconnect
```

You can also target the bar widget when it is placed:

```sh
noctalia msg plugin luixbits/casio-deck:status focused press C
```

## Button Actions

Each trigger can use a preset or one configured shell command:

- `button_a_preset`
- `button_a_command`
- `button_b_preset`
- `button_b_command`
- `button_c_preset`
- `button_c_command`
- `button_d_preset`
- `button_d_command`
- `lower_left_preset`
- `lower_left_command`
- `lower_right_preset`
- `lower_right_command`
- `timeplace_preset`
- `timeplace_command`
- `finder_preset`
- `finder_command`
- `unknown_preset`
- `unknown_command`

Presets include:

- `notification_test`
- `media_play_pause`
- `volume_up`
- `volume_down`
- `screenshot_region`
- `clipboard`
- `launcher`
- `lock`

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
  click actions for status/settings/mock testing.
- `toggle`: control-center shortcut for quick connect/mock actions.
- `dashboard`: temporary four-tab desktop widget for Overview, Connection,
  Functions, and About.
- Settings gear: command text editing under Settings -> Plugins -> Casio Deck.

Native Clipboard/System-style plugin panels are not available from the current
Noctalia v5 Luau plugin API. This is the reason the active v5 bar widget cannot
open a tabbed dropdown on left click. When Noctalia exposes a plugin panel
surface, the same tab structure should move from the desktop widget into the
bar-click dropdown. The old `qml/` prototype is kept only as a local experiment;
it is not the shareable v5 plugin path.

## Desktop Test Dashboard

Until v5 plugin panels exist, use the desktop widget dashboard to test the
actual bridge behavior with a visible UI.

Tabs:

- Overview: connection state, helper state, last trigger/action, errors, press
  count, and quick actions.
- Connection: model selection, helper controls, scan action, support state, and
  detected watch results.
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
box_width = 540.0
box_height = 0.0
rotation = 0.0
```

Useful commands:

```sh
noctalia msg desktop-widgets-show
noctalia msg desktop-widgets-edit
noctalia msg plugin luixbits/casio-deck:dashboard all press A
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
capabilities casio_abl100we_3565 lower_left,lower_right,timeplace,finder,unknown
scan casio_abl100we_3565 CASIO_ABL-100WE-1A XX:XX:XX:XX:XX:XX experimental
watch casio_abl100we_3565 CASIO_ABL-100WE-1A XX:XX:XX:XX:XX:XX
connect
press lower_right
press finder
error optional message
disconnect
```

For local testing without hardware:

Set `helper_command` to
`/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh`.

To test invalid helper lines:

Set `helper_command` to
`/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --invalid`.

For local ABL-100WE-style testing without hardware:

Set `helper_command` to
`/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --model abl100we`.

To make the desktop widget Scan button run the mock scan path, set
`scan_command` to:

```text
CASIO_DECK_MOCK_DELAY=0 /home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --model abl100we
```

## ABL-100WE Connection Test

The experimental helper is where the GShockTimeServer-style Bluetooth work
lives. It uses `gshock-api` and `bleak` through a Nix-friendly runner. It does
not set time or write watch settings.

Before testing with the watch, keep phone Bluetooth or the CASIO WATCHES app off
so the watch does not connect to the phone instead of the PC.

Start a Bluetooth capture:

```sh
sudo btmon -w "abl100we-$(date +%Y%m%d-%H%M%S).cfa"
```

Run the helper manually first:

```sh
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --loop --debug
```

Then try the watch operations:

- Hold `C` for at least three seconds to connect.
- Press `D` in Timekeeping Mode for TIME&PLACE.
- Hold `D` for Phone Finder.

If the helper works, set `watch_model` to `casio_abl100we_3565` and
`helper_command` to:

```text
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --loop
```

The helper owns hardware-specific Bluetooth, BLE, serial, evdev, GPIO,
reconnect, and debounce logic. The plugin owns Noctalia state, UI,
notifications, and user-configured button actions.
