# Casio Deck Plan

This file captures the current project context so the `casio-deck/` directory can
be opened directly in an editor without losing the design decisions.

## Goal

Build a Noctalia v5 plugin that eventually lets a Casio watch act like a small
stream-deck-style controller.

The first milestone is not hardware support. The first milestone is a clean,
loadable Noctalia plugin foundation with:

- plugin manifest and catalog entry
- headless service
- bar widget
- control-center shortcut
- mock button events
- IPC smoke tests
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
- Publishes `status` and `event`.
- Currently uses mock button events.

`status.luau`

- Bar `[[widget]]`.
- Shows watch connection/status with built-in glyphs.
- Left click sends mock button `A`.
- Right click sends mock button `B`.
- Middle click sends mock button `C`.
- Forwards widget IPC into the bridge through `noctalia.state`.

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

## Next Foundation Steps

1. Add a tiny mock helper script that emits the future helper protocol.
2. Teach `bridge.luau` to optionally read `helper_command` with
   `noctalia.runStream(...)`.
3. Keep IPC commands working as a test backdoor.
4. Add command/action mapping settings once the real button vocabulary is known.
5. Add reconnect/error state once there is a real helper process.
6. Add screenshots or short GIFs to the README after the widget is visually stable.

## Future Helper Protocol

The hardware helper should print one normalized event per line:

```text
connect
press A
press B
press C
press D
disconnect
```

The helper should own hardware-specific details:

- Bluetooth, HID, serial, or evdev access
- permissions
- reconnects
- debouncing
- raw event decoding

The Noctalia plugin should own desktop-facing state and UI.

## Open Questions

- Which exact Casio watch model will be used?
- Does it expose buttons over Bluetooth, HID, serial, or another protocol?
- Which buttons should map to which desktop actions?
- Should actions be fixed in the plugin or user-configurable through settings?
- Should the first real integration be a helper in Python, Rust, or shell?

## Current Known Good State

As of the initial foundation:

- The repo is pushed to GitHub.
- `luixbits/casio-deck` appears from the local path source.
- The bridge service responds to IPC.
- Noctalia config validation passes.
- Hardware support has not started yet.
