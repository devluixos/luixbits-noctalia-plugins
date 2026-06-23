# Casio Deck Current Plan

## Product Goal

Casio Deck is a portable Noctalia v5 plugin that turns supported Casio Bluetooth
watch events into desktop actions. The active target is the Casio ABL-100WE-1A
/ module 3565. The architecture stays model-adapter based so additional Casio
watches can be added later without rewriting the Noctalia UI/action layer.

## Active Architecture

- `plugin.toml`: static Noctalia manifest and settings.
- `entries/service/bridge.luau`: isolated service VM for state, helper protocol
  parsing, trigger validation, action resolution, notifications, and command
  execution.
- `dashboard.luau`: temporary four-tab desktop widget UI until Noctalia exposes
  plugin-owned bar dropdown panels. This stays at plugin root because the
  current Noctalia desktop-widget loader watches/loads that root path.
- `entries/widgets/status.luau`: compact bar widget that reflects bridge state.
- `entries/shortcuts/shortcut.luau`: control-center shortcut.
- `data/models.deck`: model ids, support level, capabilities, and triggers.
- `data/actions.deck`: preset actions and trigger metadata.
- `helper/`: experimental Python Bluetooth helper using `bleak`/`gshock-api`.

The archived QML prototype lives in `../archive/casio-deck-qml/` and is not
part of the shared v5 plugin.

## Helper Structure

The Python helper is split by responsibility:

- `bluez.py`: BlueZ `bluetoothctl` pairing/trust helpers.
- `debounce.py`: duplicate trigger suppression.
- `model_types.py`: shared model adapter shape.
- `models.py`: model registry.
- `protocol.py`: helper stdout protocol emit/log helpers.
- `runtime.py`: model-to-runtime adapter dispatch.
- `adapters/abl100/model.py`: ABL-100WE metadata, aliases, triggers, and
  capabilities.
- `adapters/abl100/runtime.py`: ABL-100WE adapter entry point and session
  dispatcher.
- `adapters/abl100/action_sessions.py`: short app transactions used for
  desktop actions and the legacy connection-trigger/poll paths.
- `adapters/abl100/pairing_session.py`: explicit setup/pair transaction.
- `adapters/abl100/fixed_sessions.py`: experimental held/raw BLE research
  sessions.
- `adapters/abl100/app_connection.py`: GShock/app-session connection setup.
- `adapters/abl100/fixed_connection.py`: low-level Bleak fixed/raw connection.
- `adapters/abl100/device.py`: scan/device-name helpers.
- `adapters/abl100/session_common.py`: app-info handshake and pressed-button
  initialization.
- `adapters/abl100/post_init.py`: Smart Sync style post-init probes.
- `adapters/abl100/app_info.py`: Casio app-info scratchpad profile policy.
- `adapters/abl100/triggers.py`: GShock button-to-trigger normalization.
- `adapters/abl100/time_sync.py`: minimal Casio current-time packet and
  optional time sync.

Contributor hooks:

- Add watch Bluetooth behavior under `helper/src/casio_deck_helper/adapters/`.
- Register helper-side models in `helper/src/casio_deck_helper/models.py`.
- Add Noctalia-visible model capabilities in `data/models.deck`.
- Add preset commands, trigger labels, and setting keys in `data/actions.deck`.
- Add command presets in `data/actions.deck`; add bridge code only when a
  future action genuinely cannot be represented as a shell command.

## UI Direction

The dashboard is the temporary setup surface and keeps four tabs:

- Overview: listener state, paired/watch status, last trigger/action, errors.
- Connection: model selection, pair/setup, listener start/stop, current device.
- Logs: helper state, traces, raw packets, and recent connection log.
- Functions: configure supported triggers through preset cycling and test
  buttons.
- About: concise project/support info and external links.

The widget should keep plugin-owned fixed size `520x384`; Noctalia desktop
widget config should use `box_width = 0.0` and `box_height = 0.0`.

The UI is still one Luau entry script because Noctalia v5 entries run in
isolated VMs and we do not have a confirmed `require(...)`/module hot-reload
contract for sibling Luau files. Current cleanup keeps code sections explicit
inside root `dashboard.luau` and moves shared model/action data to `.deck`
registry files.

## Current ABL-100WE Behavior

Confirmed usable watch-initiated triggers:

- `lower_right`: short lower-right action session, default Teams audio accept.
- `finder`: long lower-right action session, default output mute toggle.
- `lower_left`: long lower-left action session, default lock screen.

Short lower-left changes watch mode locally and is not currently a BLE action
event. Full four-button behavior would need deeper protocol work, a different
watch mode, or a different supported watch.

## Next Work

1. Keep validation focused on the active Luau plugin and helper, not archived
   QML.
2. Keep `entries/service/bridge.luau` and `dashboard.luau` behavior stable
   while future watches are added through helper adapters plus `data/*.deck`.
3. Split `dashboard.luau` only when Noctalia v5 confirms stable sibling Luau
   module loading for desktop widgets; until then keep widget sections explicit.
4. Improve Functions UI only when Noctalia exposes real select/dropdown inputs.
5. Move the dashboard tab structure into a bar-click panel when Noctalia v5
   exposes plugin-owned dropdown panel APIs.

## Validation

Run from the repo root:

```sh
./scripts/validate.sh
python -m compileall casio-deck/helper/src
noctalia config validate
```

Useful smoke checks after Noctalia loads the plugin:

```sh
./scripts/dev/smoke-casio-deck.sh abl100we
noctalia msg plugin luixbits/casio-deck:bridge all status
```

Action-triggering smoke tests can run real desktop commands. Opt in explicitly:

```sh
CASIO_DECK_SMOKE_RUN_ACTIONS=1 ./scripts/dev/smoke-casio-deck.sh abl100we
```
