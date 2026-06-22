# Casio Deck Plan

This file captures the current project context so the `casio-deck/` directory can
be opened directly in an editor without losing the design decisions.

## Goal

Build a Noctalia v5 plugin that lets a Casio watch, helper process, or mock
event source act like a small stream-deck-style controller.

The current milestone is a functional V1 foundation. Hardware support stays
outside the plugin behind a helper process, while Noctalia owns state, UI, and
desktop actions.

V1 includes:

- plugin manifest and catalog entry
- headless bridge service
- bar widget
- four-tab desktop widget setup UI
- control-center shortcut
- mock button events
- IPC smoke tests
- optional helper stream through `helper_command`
- user-configured trigger presets and shell commands
- experimental ABL-100WE helper for connection and trigger testing
- model-adapter registry for future Casio BLE watches
- documented helper protocol for future hardware work

## Repository

Repository:

```text
git@github.com:devluixos/luixbits-noctalia-plugins.git
```

Local source root:

```text
/home/luiz/projects/noctalia-plugins
```

Plugin directory:

```text
/home/luiz/projects/noctalia-plugins/casio-deck
```

Noctalia plugin id:

```text
luixbits/casio-deck
```

Important: Noctalia plugin sources point at the source root, not the plugin
directory. Use `/home/luiz/projects/noctalia-plugins`, not
`/home/luiz/projects/noctalia-plugins/casio-deck`.

## Current Structure

```text
noctalia-plugins/
  catalog.toml
  README.md
  LICENSE
  docs/
    helper-protocol.md
    plugin-source.md
  scripts/
    validate.sh
    smoke-casio-deck.sh
  casio-deck/
    PLAN.md
    README.md
    plugin.toml
    bridge.luau
    helper/
    examples/mock-helper.sh
    qml/
      manifest.json
      Main.qml
      BarWidget.qml
      Panel.qml
      Settings.qml
    dashboard.luau
    status.luau
    shortcut.luau
    translations/en.json
    assets/README.md
```

## Current Runtime Design

`bridge.luau`

- Headless `[[service]]`.
- Owns shared plugin state.
- Accepts commands from IPC and from `noctalia.state`.
- Optionally starts `helper_command` with `noctalia.runStream(...)`.
- Parses the V1 model-aware helper protocol.
- Tracks selected model capabilities and rejects unsupported triggers.
- Publishes `status` and `event`.
- Resolves trigger actions from advanced mapping, preset settings, then custom
  shell command settings.
- Runs configured desktop commands with `noctalia.runAsync(...)`.
- Records invalid helper lines as `last_error`.

`status.luau`

- Bar `[[widget]]`.
- Shows watch connection/status with built-in glyphs.
- Left click is reserved for the future plugin dropdown panel, but the current
  Noctalia v5 Luau API cannot open plugin-owned panels.
- Right click reports the bridge status.
- Middle click sends mock button `A`.
- Forwards widget IPC into the bridge through `noctalia.state`.

`dashboard.luau`

- Desktop `[[desktop_widget]]`.
- Temporary v5-native testing surface until plugin panels exist.
- Uses tabs: Overview, Connection, Functions, About.
- Renders bridge status, watch/helper details, model selection, discovered watch
  results, trigger mappings, and trigger test buttons.
- Sends commands to the same `noctalia.state.command` bridge path as the bar.

`shortcut.luau`

- Control-center `[[shortcut]]`.
- Left click connects or sends mock button `A`.
- Right click disconnects.

Shared state keys:

```text
status
event
command
```

`status` includes:

```text
connected
mode
helper_configured
helper_ready
helper_started
helper_capabilities
watch_model
watch_model_name
watch_model_module
watch_model_support
watch_name
watch_address
available_triggers
available_capabilities
discovered_watches
last_trigger
last_button
last_action
last_action_detail
last_source
last_error
press_count
heartbeat
updated_at
```

## How To Load Locally

In Noctalia Settings:

1. Open `Settings -> Plugins`.
2. Add source.
3. Choose `Path`.
4. Name: `local-dev`
5. Location: `/home/luiz/projects/noctalia-plugins`
6. Enable `Casio Deck`.
7. Add `luixbits/casio-deck:status` to the bar.

In the NixOS/Home Manager setup, local testing is wired from:

```text
/home/luiz/luix_nix_config/home/modules/niri/noctalia/default.nix
```

That module points Noctalia at:

```text
${config.home.homeDirectory}/projects/noctalia-plugins
```

and places widget instance `casio_deck` in the bar.

## Validation

From the repository root:

```sh
./scripts/validate.sh
```

Expected output:

```text
ok
```

This validates:

- `catalog.toml` parses
- every catalog entry has a matching plugin directory
- every plugin manifest id matches the catalog id
- entry scripts exist
- translation JSON parses
- manifest translation keys exist in `translations/en.json`
- legacy QML experiment `manifest.json` entry points exist

## Smoke Test

After Noctalia has loaded and enabled the plugin:

```sh
./scripts/smoke-casio-deck.sh
```

Equivalent commands:

```sh
noctalia msg plugin luixbits/casio-deck:bridge all connect
noctalia msg plugin luixbits/casio-deck:bridge all press A
noctalia msg plugin luixbits/casio-deck:bridge all press B
noctalia msg plugin luixbits/casio-deck:bridge all status
noctalia msg plugin luixbits/casio-deck:bridge all disconnect
```

If the bar widget is placed:

```sh
noctalia msg plugin luixbits/casio-deck:status focused press C
```

## Functional V1 Decisions

V1 is a button deck, not a full watch automation suite.

UI tabs:

- Overview: connection state, selected watch, helper state, last trigger/action,
  error, press count, diagnostics, and quick actions.
- Connection: model selection, helper start/scan/connect actions, support level,
  and detected watch results.
- Functions: watch-specific triggers and the active preset/custom-command
  mapping for each trigger.
- About: what Casio Deck does, current hardware support, LuixBits channel URL,
  and future explanation video URL.

Model adapters:

- `generic_abcd`: supported mock/manual trigger model.
- `casio_abl100we_3565`: first experimental real Casio adapter.
- `future_casio_ble`: placeholder for unsupported future watches.

Supported plugin settings:

```text
helper_command
notify_on_press
watch_model
trigger_action_map
youtube_channel_url
explanation_video_url
button_a_preset
button_a_command
button_b_preset
button_b_command
button_c_preset
button_c_command
button_d_preset
button_d_command
lower_left_preset
lower_left_command
lower_right_preset
lower_right_command
timeplace_preset
timeplace_command
finder_preset
finder_command
unknown_preset
unknown_command
```

Action resolution order:

1. `trigger_action_map`, for advanced mappings like
   `lower_right=preset:media_play_pause`.
2. Per-trigger preset setting.
3. Per-trigger custom shell command.
4. No action, but still record the press and publish state.

The helper process may produce button events, but it must not send desktop
commands. The bridge only executes command strings that come from Noctalia
settings.

Keep out of V1:

- EDB-120 data-bank writing
- time sync
- button-hold mappings
- full settings editor
- launcher provider
- action profiles or macro system

Custom dropdown panels are also out of the portable v5 V1 because Noctalia v5
currently exposes bar widgets, shortcuts, launcher providers, desktop widgets,
and services to plugins, but not a plugin-owned `[[panel]]` entry or
`barWidget.openPanel(...)`/`pluginApi.openPanel(...)` equivalent for Luau
widgets. Do not use a desktop widget as a fake panel; it renders on the desktop
bottom layer and does not match the bar-click panel interaction.

Use the desktop widget dashboard for development/testing instead. It is not a
dropdown, but it is v5-native and exercises the real bridge/command path:

```toml
[desktop_widgets.widget.casio_deck_dashboard]
type = "luixbits/casio-deck:dashboard"
```

Runtime resolves that type after plugin loading. `noctalia config validate` may
still warn because validation checks desktop widget types before plugin source
scanning in this build.

Legacy local UI note:

- `casio-deck/qml/` is kept as an old local experiment only.
- The shareable plugin path is `plugin.toml` plus Luau entries.
- The active temporary setup UI is the v5-native `dashboard.luau` desktop
  widget.

## Helper Protocol

The hardware helper should print one normalized event per line.

```text
ready <helper> <version> <model>
model <model> <display_name> module=<number> support=<level>
capabilities <model> <comma-separated-trigger-list>
scan <model> <name> <address> <support>
watch <model> <name> <address>
connect
press A
press B
press C
press D
press lower_left
press lower_right
press timeplace
press finder
press unknown
error <message>
disconnect
```

The helper should own hardware-specific details:

- Bluetooth, HID, serial, or evdev access
- permissions
- reconnects
- debouncing
- raw event decoding

The Noctalia plugin should own desktop-facing state and UI.

Local mock helper:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh
```

Invalid-line test:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --invalid
```

ABL-style mock:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/examples/mock-helper.sh --model abl100we
```

## ABL-100WE Test Helper

The experimental helper is:

```text
/home/luiz/projects/noctalia-plugins/casio-deck/helper
```

Run it through:

```sh
/home/luiz/projects/noctalia-plugins/scripts/run-abl100-helper.sh --model abl100we --loop --debug
```

Tomorrow test flow:

1. Keep the phone app/Bluetooth away from the watch during PC tests.
2. Start capture: `sudo btmon -w "abl100we-$(date +%Y%m%d-%H%M%S).cfa"`.
3. Run the helper manually with `--loop --debug`.
4. Hold `C` for at least three seconds to connect.
5. Press `D` in Timekeeping Mode for TIME&PLACE.
6. Hold `D` for Phone Finder.
7. If stdout emits useful `press <trigger>` lines, set Noctalia `helper_command`
   to the same runner without `--debug`.

## Later Hardware Questions

- Which exact Casio watch model will be used first?
- Will the helper read BLE, HID, serial, evdev, GPIO, or another transport?
- Should a future helper be Python, Rust, shell, or microcontroller-specific?
- Which button-hold or multi-button events are worth adding after simple
  presses work?

## Current Known Good State

As of the lean V1 foundation:

- The repo is pushed to GitHub.
- `luixbits/casio-deck` appears from the local path source.
- The bridge service responds to IPC.
- The bridge can consume an optional helper stream.
- Buttons A/B/C/D can run user-configured shell commands.
- Invalid helper lines are recorded as `last_error`.
- Noctalia config validation passes.
- Real hardware support has not started yet.
