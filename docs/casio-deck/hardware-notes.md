# Casio Deck Historical Notes

This file preserves the long working plan and hardware investigation notes that
used to live in `casio-deck/PLAN.md`. It is intentionally historical. The
current short implementation plan lives in `casio-deck/PLAN.md`, and the active
helper protocol lives in `docs/helper-protocol.md`.

## Previous Working Plan

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
- opt-in helper autostart through `autostart_helper`
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
    docs/casio-deck/persistent-connection-plan.md
    README.md
    plugin.toml
    bridge.luau
    helper/
      pyproject.toml
      src/casio_deck_helper/
        cli.py
        runtime.py
        models.py
        protocol.py
        debounce.py
        abl100.py
    helper/examples/mock-helper.sh
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
- Does not start `helper_command` at plugin load unless
  `autostart_helper = true`; dashboard/IPC Start can still launch it manually.
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
- Uses tabs: Overview, Connection, Logs, Functions, About.
- Keeps the main tabs flush at the top so large tab content cannot push them
  outside the clickable area.
- Keeps Connection lean: model selection, detected device, Scan, Pair, Listener.
- Moves helper trace/debug output to the Logs tab. The current Luau desktop
  widget API does not expose a confirmed scroll container, so logs are capped.
- Renders bridge status, watch/helper details, model selection, discovered watch
  results, trigger mappings, and trigger test buttons.
- Sends commands to the same `noctalia.state.command` bridge path as the bar.

`shortcut.luau`

- Control-center `[[shortcut]]`.
- Left click connects or sends mock button `A`.
- Right click disconnects.

## Widget Improvement Plan

Keep the UI in the Noctalia v5 visual style and optimize it as a compact
desktop widget/control surface. The widget should not try to be a full settings
application until plugin-owned bar dropdown panels or richer widget controls are
available.

### Overall Layout

- Keep the main tabs flush at the top:
  - Overview
  - Connection
  - Logs
  - Functions
  - About
- Keep the widget compact enough to fit on screen without hiding the tab row.
- Avoid one giant mixed Connection page. Connection state, connection actions,
  logs, and function mapping should be separated.
- Prefer one clear primary action per page.
- If a real scroll container becomes available to Luau desktop widgets, use a
  fixed widget height and scroll only the active tab content. Until then, use
  compact pages and capped lists.

### Overview

Purpose: current state at a glance.

Show only the important live information:

- connection state: offline, listening, pairing, connected, reconnecting, error
- paired device state: verified/saved or not verified
- selected watch model
- detected watch name and BLE address when known
- helper/listener state: configured, running, ready
- last trigger
- last action
- last error
- total press count

Controls:

- Start Listener
- Pair/Setup
- Reset Status

Do not show detailed logs, model cards, or long explanations here.

### Connection

Purpose: connect to a watch and manage the Bluetooth/helper session.

Keep it lean:

- watch selector
- selected/detected device
- Pair/Setup button
- Start Listener button
- Scan button
- short support/status note

Watch selector:

- Preferred UI: dropdown/select with the model registry.
- Current fallback: compact previous/next or selected model row, because the
  current Luau widget API does not expose a confirmed dropdown component.
- V1 options:
  - Casio ABL-100WE-1A / module 3565
  - Generic A/B/C/D mock
  - Unsupported Casio BLE watch placeholder

Remove from this page:

- detailed trace rows
- watch test matrix
- long adapter descriptions
- low-level repair/monitor controls unless they are hidden behind an advanced
  page or a diagnostics mode

### Logs

Purpose: show what is going on without cluttering Connection.

Show:

- latest helper protocol lines
- latest connection state changes
- latest raw/debug summary
- invalid helper lines or errors

Keep it bounded:

- show the newest 8-12 rows if scrolling is available
- otherwise show the newest 4-6 rows
- include Clear Log/Reset Status

The log page is for diagnostics only. It should not be required for normal use.

### Functions

Purpose: configure what watch inputs do.

Show watch-specific triggers from the selected model adapter.

For ABL-100WE V1:

- lower_right: confirmed short lower-right action
- finder: confirmed long lower-right action
- lower_left: confirmed long lower-left connection action

Keep out of the normal Functions UI for now:

- `lower_right_layer_2` / `lower_right_layer_3`: experimental virtual layer
  workaround, too confusing for V1.
- `timeplace`: unconfirmed/not separately exposed yet.
- `unknown`: diagnostic fallback, useful in Logs/backend but not as a normal
  user-configurable input.

Each trigger row should include:

- trigger name
- short description/support note
- current selected function
- function selector
- Test button

Function selector:

- Preferred UI: dropdown/select with presets.
- Current fallback: previous/next buttons cycling through presets.
- If text input becomes available, add a Custom Command field per trigger.
- Until text input is available, custom commands stay in plugin settings or the
  advanced `trigger_action_map`.

Preset descriptions should be visible in a compact detail area when a preset is
selected. Example presets:

- Notification test: sends a desktop notification.
- Lock screen: locks the current session.
- Teams accept audio: sends the Teams keyboard shortcut to accept with audio.
- Teams toggle mute: sends the Teams mute shortcut.
- Output mute: toggles system output mute.
- Mic mute: toggles default input mute.
- Clipboard: opens the Noctalia clipboard panel.
- Launcher: opens the launcher.
- Next layer: changes the active Casio Deck action layer.

Custom command examples:

```sh
notify-send "Casio Deck" "Lower-right pressed"
loginctl lock-session
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
noctalia msg panel-open clipboard
```

Safety rules:

- helper output must never contain executable command text
- commands always come from plugin settings or widget-saved mappings
- show clearly when a trigger is unmapped

### About

Purpose: explain the plugin and link to project/channel pages.

Keep:

- short description of Casio Deck
- current support level: ABL-100WE experimental
- GitHub link
- LuixBits YouTube link

Video embedding:

- Not part of V1. Keep About simple with links only.

### Implementation Order

1. Done: split current Connection into separate top-level Connection and Logs tabs.
2. Done: simplify Overview to live state only.
3. Done: simplify Connection to select/scan/pair/listen only.
4. Done: keep model selection as a compact fallback selector; replace with dropdown
   only if the active widget API supports it.
5. Done: improve Functions rows with preset descriptions and clearer support notes.
   Done: normal ABL Functions view now shows only the three confirmed inputs.
6. Done: add Custom Command display/examples; make editing available only when text
   input is supported or through plugin settings.
7. Done: keep About simple with GitHub and YouTube links.
8. Done: re-run `./scripts/validate.sh`.

Shared state keys:

```text
status
event
command
```

`status` includes:

```text
connected
connection_state
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
trigger_counts
last_raw
raw_count
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
- helper foundation tests pass through Python `unittest`

## Smoke Test

After Noctalia has loaded and enabled the plugin:

```sh
./scripts/dev/smoke-casio-deck.sh abl100we
./scripts/dev/smoke-casio-deck.sh generic
```

Equivalent ABL commands:

```sh
noctalia msg plugin luixbits/casio-deck:bridge all select_model casio_abl100we_3565
noctalia msg plugin luixbits/casio-deck:bridge all start_helper
noctalia msg plugin luixbits/casio-deck:bridge all press lower_left
noctalia msg plugin luixbits/casio-deck:bridge all press lower_right
noctalia msg plugin luixbits/casio-deck:bridge all status
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
  detected watch results, and live watch-test observation counts.
- Functions: watch-specific triggers and the active preset/custom-command
  mapping for each trigger, including how often each trigger was observed this
  session.
- About: what Casio Deck does, current hardware support, LuixBits channel URL,
  and future explanation video URL.

Model adapters:

- `generic_abcd`: supported mock/manual trigger model.
- `casio_abl100we_3565`: first experimental real Casio adapter.
- `future_casio_ble`: placeholder for unsupported future watches.

Helper architecture:

- `cli.py`: generic command-line parsing and repeated helper loop.
- `runtime.py`: maps a selected model adapter to its helper runtime.
- `models.py`: stable model ids, aliases, scan filters, trigger vocabulary, and
  support level.
- `protocol.py`: stdout protocol emission and stderr-only library logging.
- `debounce.py`: shared trigger debounce helper.
- `abl100.py`: the first concrete BLE runtime. Default `timeserver` mode mirrors
  GShockTimeServer: scan/pair/connect, read the connection initiator, run one
  action such as time sync, and disconnect. The time-sync action is now a
  minimal direct current-time packet implemented in Casio Deck, not the broader
  `gshock-api.set_time()` sequence. Experimental `fixed` mode tries to hold the
  BLE link for raw notification research; fallback diagnostic modes use
  `gshock-api` for the ABL-100WE/module 3565 connection-trigger path.
- `helper/tests/`: stdlib unit tests for model aliases, scan matching, button
  mapping, and debounce behavior.

Supported plugin settings:

```text
helper_command
autostart_helper
scan_command
pair_command
monitor_command
repair_command
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
- broad time sync/settings automation beyond the minimal ABL setup packet
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
state waiting
state connecting
state pairing
state connected
state subscribed
state initializing
state ble_held
state session_complete
state action_complete
state action_failed
state reconnecting
state disconnected
state stopped
state app_handshake_failed
watch <model> <name> <address>
connect
raw <uuid-or-source> <hex-payload>
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
/home/luiz/projects/noctalia-plugins/casio-deck/helper/examples/mock-helper.sh
```

Invalid-line test:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/helper/examples/mock-helper.sh --invalid
```

ABL-style mock:

```sh
/home/luiz/projects/noctalia-plugins/casio-deck/helper/examples/mock-helper.sh --model abl100we
```

## ABL-100WE Test Helper

The experimental helper is:

```text
/home/luiz/projects/noctalia-plugins/casio-deck/helper
```

Run it through:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --once --debug
```

The product goal is still button monitoring. On ABL-100WE, the confirmed path
today is narrower: the helper can monitor the Bluetooth session initiator
(`lower_left` confirmed) and emit it as one `press <trigger>` event. Full
physical-button streaming while connected remains a research track until raw
captures prove the watch exposes those events.

Use `--loop` only for controlled research captures. For UI-driven safe testing,
use the one-shot action path:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --session-mode action --once --scan-timeout 60 --connect-timeout 25 --app-init-timeout 25 --debug
```

Current watch test flow:

1. Keep the phone app/Bluetooth away from the watch during PC tests.
2. Prefer the capture runner:
   `/home/luiz/projects/noctalia-plugins/scripts/dev/capture-abl100-session.sh --seconds 180`.
   It records helper stdout/stderr and starts `btmon` when available.
3. Prefer Noctalia-started helper mode through `helper_command`; use terminal
   `--loop --debug` only when collecting raw diagnostics.
4. Put the watch into Bluetooth connection/search mode once.
5. Watch for `state session_complete` in the dashboard. In default ABL mode the
   watch should leave CNCT/search mode after the action completes and the helper
   disconnects.
6. Use `--session-mode fixed` only when researching whether a held app session
   can produce raw notification packets.
7. If fixed mode cannot hold the link, use
   `--session-mode connection-trigger --debug` as the fallback capture path.
8. If the watch closes the BLE link, the helper should emit `disconnect` and
   return to waiting/reconnecting without terminal work.

Current local testing config keeps `helper_command` configured for the
dashboard Start button, but leaves `autostart_helper = false` so plugin reloads
do not start a helper process. The local helper command uses one-shot action
mode: `--session-mode action --once --scan-timeout 60 --connect-timeout 25
--app-init-timeout 25`.
The local `pair_command` is wired to non-destructive setup and the local
`repair_command` is wired to the destructive `--repair-pairing` setup flow.

Loop mode is not safe as a default for ABL-100WE. On 2026-06-23 the helper
completed clean action sessions (`press lower_left`, `state session_complete`,
`disconnect`), but repeated automatic sessions still pushed the watch into
`ERR`. One-shot mode keeps each test explicit: click Start once, trigger the
watch once, then inspect the result.

If Linux says the watch is paired but the watch still stays in CNCT/search mode,
run a deliberate repair pairing session:

```sh
/home/luiz/projects/noctalia-plugins/scripts/helper/run-abl100-helper.sh --model abl100we --setup-pairing --repair-pairing --sync-time-on-connect --once --debug --scan-timeout 120 --connect-timeout 25 --app-init-timeout 25
```

This removes the saved BlueZ device, scans by watch name, pairs again, and then
performs the Casio app-info handshake.

## Remaining Hardware Questions

- Does ABL-100WE/module 3565 expose any usable button event while connected?
  Casio's module 3565 manual says pressing any button besides `B` terminates the
  Bluetooth connection, so arbitrary always-connected button streaming may be
  blocked by watch firmware even after a correct app session.
- Does `gshock-api` expose TIME&PLACE/Finder distinctly on this model, or do we
  need deeper BLE notification/capture work?
- Which next Casio BLE models should get real adapters after ABL-100WE?
- Which button-hold or multi-button events are worth adding after simple
  presses work?

## Pairing-First Plan

The next priority is no longer repeated action testing. We need a pairing-first
flow that mirrors the phone-app architecture more closely.

What the phone-style code does:

- Creates an OS-level device association/pairing.
- Stores the selected watch address/name.
- Observes device presence instead of constantly opening GATT sessions.
- Calls `waitForConnection(address)` only when the watch appears.
- Completes app-info initialization after the watch-initiated connection.

Linux equivalent for Casio Deck:

1. Add a dedicated Pair/Setup mode separate from Start Helper.
2. Pairing mode should:
   - stop any running helper;
   - optionally remove the stale BlueZ device record;
   - scan for `CASIO ABL-100WE`;
   - connect with BLE pairing enabled once;
   - verify BlueZ `Paired`, `Bonded`, `Trusted`;
   - complete the Casio app-info handshake;
   - save the watch address/model/name in plugin state/settings;
   - disconnect and stop.
3. Normal mode should not repeatedly reconnect. It should:
   - passively wait/scan for the saved address;
   - connect only when the watch advertises because the user started a watch
     Bluetooth action;
   - read the session initiator;
   - emit one `press <trigger>`;
   - disconnect and stop, or return to idle only after an explicit UI command.
4. Monitor research mode should be separate and clearly marked experimental:
   - keep the BLE session open;
   - subscribe to all notify characteristics;
   - capture raw packets while pressing buttons;
   - only promote full button monitoring if real packets appear.

Important distinction:

- BlueZ already reports the watch as paired/bonded/trusted. That is necessary
  but not enough.
- Casio app-level pairing means the watch and helper complete the app/session
  setup in a way the watch accepts without showing `ERR`.
- The ABL-100WE has confirmed `lower_left` session-initiator events, but has
  not confirmed arbitrary button-click streaming.

Implementation status:

- Done: helper `--setup-pairing` mode with strict one-shot behavior.
- Done: dashboard Pair/Setup button runs `pair_command`, not `helper_command`.
- Done: dashboard labels distinguish Pair, Session, Scan, and Monitor.
- Done: separate `monitor_command` setting for fixed/raw capture research.
- Done: normal Pair no longer removes the Linux bond on every click; destructive
  remove-and-repair stays on the Repair button.
- Done: setup pairing now reads the connection initiator after app-info but does
  not emit a desktop `press` action.
- Done: Pair/Repair setup can write the minimal current-time packet with
  `--sync-time-on-connect`, matching the proven GShockTimeServer transaction
  shape before disconnect.
- Kept: no `--loop` default for ABL-100WE.

Next implementation steps:

- Test Pair/Setup from the widget with the watch in CNCT/search mode.
- If Pair/Setup still shows watch-side `ERR`, capture the helper log and btmon
  trace and compare against the Android app's association/app-info sequence.
- If Pair/Setup succeeds, test one Session from the widget and map any confirmed
  ABL triggers beyond `lower_left`.

## Current Known Good State

As of the fixed BLE helper foundation:

- The repo is pushed to GitHub.
- `luixbits/casio-deck` appears from the local path source.
- The bridge service responds to IPC.
- The bridge can consume an optional helper stream and track `connection_state`.
- The bridge publishes per-trigger observation counts through `trigger_counts`.
- The bridge accepts `raw <uuid> <hex>` helper lines and publishes `last_raw`
  plus `raw_count` without treating raw packets as invalid events.
- Helper `ready`/`model`/`watch` lines now align the selected model before the
  first press arrives.
- The dashboard shows fixed-mode raw event counts separately from mapped trigger
  counts, so we can see whether the held BLE connection is actually delivering
  packets.
- The desktop dashboard is now compact enough for normal display bounds:
  narrower root width, single-column overview, shorter tabs, smaller labels, and
  compact model rows.
- Dashboard button clicks update visible UI state immediately before the bridge
  response arrives, so Start/Scan/Reset/model selection no longer look inert.
- In helper mode, UI test presses and shortcut actions no longer fake BLE
  connection state; only helper `connect`/`state connected`/`press` marks the
  watch connected.
- Buttons A/B/C/D can run user-configured shell commands.
- Invalid helper lines are recorded as `last_error`.
- Known `gshock-api` diagnostic stdout such as `Writing to handle...` is kept out
  of the plugin protocol by redirecting third-party output to stderr.
- The ABL-100WE has connected from real hardware and emitted
  `press lower_left`.
- The Python helper is split into CLI, runtime registry, model metadata,
  protocol, debounce, and ABL adapter modules.
- Helper model tests are wired into `./scripts/validate.sh`.
- `scripts/dev/capture-abl100-session.sh` records repeatable ABL helper sessions
  under ignored `captures/` directories.
- ABL scan matching no longer uses generic `CASIO` as a keyword, so other Casio
  BLE watches should not be mislabeled as ABL-100WE just because their BLE name
  contains Casio.
- Helper `--loop` keeps the process alive and waits/reconnects. Helper
  `--listener` is the product-facing alias for `--session-mode action --loop`:
  start once from Noctalia, wait for watch-initiated short sessions, emit the
  decoded trigger, return to waiting, and keep running until the plugin is
  reloaded/stopped.
- ABL-100WE now
  defaults to `action` mode: try OS-level BLE pairing/bonding, connect through
  the Casio protocol layer, complete app-info setup, decode the connection
  initiator, emit the trigger for Noctalia actions, emit
  `state session_complete`, and disconnect. This avoids pretending that the
  ABL-100WE can stay connected indefinitely and avoids writing watch settings by
  default. This is safe session-initiator monitoring, not proof that arbitrary
  button streaming works.
  `--session-mode timeserver` remains for the explicit GShockTimeServer-style
  time-sync transaction.
  `--session-mode fixed` remains for held-link/raw-notification research.
  `--session-mode raw-probe` remains for low-level Bleak notification capture.
  The legacy `--session-mode connection-trigger` path remains for diagnostics;
  experimental `--session-mode poll` remains for gshock-api research.
- Action, timeserver, and fixed modes now mirror the Android GShockAPI
  initialization order: app-info first, then `getPressedButton()`. Default
  action mode emits `session_complete` without writing watch settings;
  timeserver mode continues into time sync; fixed mode follows the ABL-safe
  lower-left app path, skips time sync for `lower_left`, probes only supported
  reads (`timer`, `watch_condition`), and then tries to hold the BLE/GATT link
  with `state ble_held`.
- `ble_held` deliberately does not mean the watch UI accepted a normal
  app-connected mode. It means Linux still has the GATT client open. The watch
  display must be checked during hardware testing.
- The time-sync step in timeserver mode now writes only Casio Deck's minimal
  current-time packet to handle `0x0E`. This replaced `gshock-api.set_time()`,
  which sent an unsupported `1F00` follow-up command on the ABL-100WE and caused
  the watch to reply `ff811f` before timing out.
- The app-info handshake is implemented locally because Python `gshock-api`
  2.0.39 uses an older app-info marker and formats some write paths
  inconsistently. Casio Deck now defaults to `--app-info-profile smart-sync`:
  if the watch returns blank app-info or the older Python marker
  `223488F4E5D5AFC829E06D02`, the helper writes the newer Android
  GShockAPI/SmartSync scratchpad marker `229300000000000000000000`. The
  `legacy-python` and `keep` profiles remain available for comparison.
- The key product correction is that ABL-100WE/module 3565 is
  `alwaysConnected = false` in the referenced Smart Sync/Webapp model registry.
  V1 should treat watch presses as session initiators that can run actions, not
  as continuous arbitrary button streaming.
- The helper emits `trace ...` protocol lines for scan, pair, connect,
  characteristics, writes, raw notifications, button decode, app-info, and time
  sync. The bridge publishes `connection_log`, `last_trace`, and `trace_count`
  so the dashboard Connection tab can show the recent connection sequence.
- Helper logs are also persisted to `~/.cache/casio-deck/helper.log` so failed
  watch attempts can be inspected outside the widget.
- BlueZ currently reports the ABL-100WE as `Paired: yes`, `Bonded: yes`, and
  `Trusted: yes`; the helper now detects this and skips re-pairing on normal
  connection attempts.
- Fixed mode now waits one second after GATT connect before service/notify
  setup, matching Smart Sync's browser connection path.
- Fixed mode no longer probes `home_time` on ABL-100WE. Real hardware answered
  `ff811f` to `1F00`, which means module 3565 rejected the world-city/home-time
  request and then the probe timed out.
- The helper now prefers the known paired Casio address and uses
  `BleakScanner.find_device_by_address()` before connecting. This replaced the
  previous long scanner path and prevents an indefinite `state connecting`
  hang: failed attempts produce `ble_find_result not_found`, return to waiting,
  and retry.
- Repair pairing was confirmed on real ABL-100WE hardware on 2026-06-23:
  BlueZ record removed, watch rediscovered as `CASIO ABL-100WE`, paired with
  `pair=True`, `Paired: yes`, `Bonded: yes`, `Trusted: yes`, and app-info
  handshake reached `state init_complete`.
- The corrected transaction mode was confirmed on real ABL-100WE hardware on
  2026-06-23 in the timeserver path: it found the paired watch, connected,
  decoded `lower_left`, completed app-info setup, wrote the direct current-time
  packet, emitted `state session_complete`, disconnected cleanly, and emitted
  `state stopped`. The current product default is now the safer `action` path,
  which follows the same transaction shape without the time write.
- Helper looping is now explicit and controllable: no `--loop` means one
  connection session, `--loop` reconnects, and `--max-attempts` bounds UI-driven
  test loops. The helper emits `state stopped` before exiting after a bounded
  run.
- The bridge now separates `helper_configured`, `helper_autostart`,
  `helper_started`, and watch `connected` state. A configured helper no longer
  auto-starts unless `autostart_helper` is enabled.
- The bridge and dashboard now separate `pair_command`, `helper_command`,
  `scan_command`, `repair_command`, and `monitor_command`. Pair/Setup is a
  deliberate one-shot app-registration flow, Session is a one-shot action
  transaction, and Monitor is an experimental held-link capture path.
- The helper now supports `--setup-pairing`, emits `paired <model> <name>
  <address>` and `state pairing_complete`, and exits without writing watch
  settings or emitting a fake trigger.
- After the 13:33 tests, logs showed BlueZ pairing succeeded
  (`paired=yes bonded=yes trusted=yes`) and app-info returned the registered
  app value, but the watch still showed `ERR`. The current correction is to stop
  repairing on every Pair click and to finish the setup transaction by reading
  the session initiator (`0x10`) after app-info and writing the minimal
  current-time packet when Pair uses `--sync-time-on-connect`, matching
  GShockTimeServer more closely without running a desktop action.
- Noctalia config validation passes.
- Confirmed real trigger support is currently `lower_left`; `lower_right`,
  `timeplace`, and `finder` are expected but not confirmed yet.
- Done: the bridge, dashboard, and bar widget now publish/show `paired` and
  `paired_at` separately from live BLE `connected`. This matters because BlueZ
  can correctly show the watch as `Paired`, `Bonded`, and `Trusted` even after
  the short ABL action/setup session has disconnected.
- Done: added advanced `saved_watch_name` and `saved_watch_address` settings so
  the bridge can remember the expected bonded watch after a plugin reload. The
  current local config is seeded with the tested ABL-100WE address.
- Done: added `--app-info-profile smart-sync` to the helper. This writes the
  newer SmartSync/GShockAPI app-info scratchpad marker `22 93 00 ...` instead
  of accepting the older Python `gshock-api` marker `22 34 88 ...` as final.
  SmartSync documents this app-info path as required to re-enable the
  lower-right action button after reset/BLE clear, so this is the next concrete
  pairing/session hypothesis to test.
- Current interpretation: after a successful Pair/Setup run, the helper exiting
  and BlueZ showing `Connected: no` is not by itself a failure. It means the
  setup transaction ended. The plugin should show `Bond: saved` and a separate
  live session state.
- Next UI test: run `Repair` once if the watch still contains the legacy
  app-info marker, then use `Session`. Do not press lower-left again while the
  watch is already flashing/searching. The session trigger is the initial watch
  operation: long lower-left for normal connection, short lower-right from Time
  mode for the action button, or long lower-right for Finder.
- Current local test setup: `helper_command` runs
  `--listener --app-info-profile smart-sync`, `autostart_helper = true`,
  `notify_on_press = false`, and all ABL trigger presets set to
  `notification_test`. No terminal helper or repeated dashboard Session click
  should be needed: plugin reload starts the background listener, the widget
  should show `listening`/`waiting`, and confirmed lower-left/lower-right
  watch-initiated sessions should produce one notification each before the
  helper returns to listening.
- Current real button finding: the ABL-100WE exposes three usable
  watch-initiated session triggers: short lower right (`lower_right`), long
  lower right (`finder`), and long lower left (`lower_left`). A normal short
  lower-left click changes watch modes and does
  not produce a BLE event. The ABL-100WE has not exposed normal physical A/B/C/D
  button clicks over BLE, so V1 must not promise four independent physical watch
  buttons on this model.
- Next research test: use `Monitor` only when deliberately investigating true
  held-link/raw button streaming. Do not mix Monitor with normal Pair/Session
  testing because it can produce confusing watch-side states.

## Background Listener Decision

The ABL-100WE app-like workflow is now:

1. Pair/Setup once if the watch bond or app-info marker is stale.
2. Let Noctalia autostart the helper with `--listener`.
3. Keep the helper alive in `state listening`/`state waiting`.
4. Let the watch initiate short BLE sessions from supported actions.
5. Decode `lower_left` or `lower_right`, execute the mapped Noctalia action,
   disconnect the live BLE session, and return to listening.

This is intentionally different from a permanent CNCT screen. The saved BlueZ
bond is the stable association; the live BLE connection is short-lived on this
watch unless later reverse engineering proves a reliable held-link action-event
stream.

## Current Action Mapping

Initial local mapping for the three confirmed ABL-100WE triggers:

- short lower-right / `lower_right`: `teams_accept_audio`
- long lower-right / `finder`: `audio_mute_toggle`
- long lower-left / `lower_left`: `lock`

Additional presets now available for any trigger:

- `audio_mute_toggle`: `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`
- `mic_mute_toggle`: `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`
- `teams_accept_audio`: `wtype -M ctrl -M shift -k s`
- `teams_accept_video`: `wtype -M ctrl -M shift -k a`
- `teams_toggle_mute`: `wtype -M ctrl -M shift -k m`
- `teams_decline_call`: `wtype -M ctrl -M shift -k d`
- `teams_leave_call`: `wtype -M ctrl -M shift -k h`

The Teams presets follow Microsoft's documented desktop shortcuts and depend on
Teams or the call UI accepting virtual keyboard input from `wtype` on Wayland.

## More Actions From Three Watch Triggers

The ABL-100WE currently exposes three real BLE session initiators, so additional
actions are implemented in software:

- Widget action picker: the Functions tab can change each trigger's preset with
  previous/next buttons. Noctalia's current Luau desktop-widget API did not show
  a dropdown/select component, so the picker uses compact buttons instead.
- Persistent runtime overrides: widget-selected presets are saved in
  `~/.cache/casio-deck/action-map.txt` and override plugin settings after
  reload.
Layer presets are not part of the normal V1 widget UI because they make the
three physical watch actions harder to understand.

## Last Verification

Checked on 2026-06-23:

- `./scripts/validate.sh` passes.
- `./scripts/validate.sh` now also runs helper unit tests.
- `bash -n scripts/dev/smoke-casio-deck.sh` passes.
- `./scripts/validate.sh` syntax-checks all repository shell scripts.
- `python -m compileall casio-deck/helper/src` passes.
- On 2026-06-23, `python -m compileall casio-deck/helper/src`,
  `./scripts/validate.sh`, and `noctalia config validate` passed after the
  Smart Sync lower-left fixed-mode changes.
- `scripts/helper/run-abl100-helper.sh --help` works through the wrapper and shows
  timeserver mode as the default helper target.
- Helper `--help` now shows
  `--session-mode timeserver,fixed,raw-probe,connection-trigger,poll`;
  timeserver mode is the default stable target, fixed mode means experimental
  held app-session handshake, and raw-probe is the old Bleak-only subscription
  test.
- `scripts/helper/run-abl100-helper.sh --model abl100we --once --scan-timeout 1
  --debug` starts timeserver mode cleanly and returns to waiting when no watch
  advertisement is visible.
- `casio-deck/helper/examples/mock-helper.sh --model abl100we` emits the model-aware
  protocol with state, watch, connect, trigger, disconnect lines.
- Real ABL-100WE session test succeeded with:
  `scripts/helper/run-abl100-helper.sh --model abl100we --session-mode timeserver
  --once --debug --scan-timeout 130 --connect-timeout 25 --app-init-timeout 25`.
  The observed sequence included `press lower_left`, `state init_complete`,
  `trace sync_time_direct ok`, `state session_complete`, `disconnect`, and
  `state stopped`.
- `noctalia msg plugins disable/enable luixbits/casio-deck` restarts the plugin.
- The restarted helper process is
  `python -m casio_deck_helper.cli --model abl100we --loop`.
- On 2026-06-23, the plugin was restarted after the app-session handshake
  change and `noctalia config validate` remained valid with the same known
  plugin widget warnings.
- `noctalia config validate` is valid, with known warnings for plugin-provided
  dashboard widget types being checked before plugin source scanning.
- Shortcut helper-mode behavior is status/start only; mock connect/disconnect
  remains available only in mock mode.
