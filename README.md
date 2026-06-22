# LuixBits Noctalia Plugins

A collection of Noctalia v5 plugins by LuixBits.

The first plugin is `casio-deck`, a foundation for turning a Casio watch into a
stream-deck-like controller for a Wayland desktop.

If you like Linux desktop customization, NixOS, Wayland, and unusual input
device projects, I document builds like this on the LuixBits YouTube channel.

## Plugins

| Plugin | ID | Status |
| --- | --- | --- |
| Casio Deck | `luixbits/casio-deck` | Foundation / ABL-100WE test helper |

## Temporary Setup UI

The portable Noctalia v5 plugin lives in `casio-deck/plugin.toml` and the Luau
files. The current v5 API does not expose the large Clipboard/System-style panel
surface yet, so Casio Deck uses a temporary `[[desktop_widget]]` setup UI with
tabs for Overview, Connection, Functions, and About.

The older `casio-deck/qml/` prototype is kept only as a local experiment. The
shareable plugin path is the v5 `plugin.toml` plus Luau entries.

When Noctalia exposes plugin-owned bar dropdown panels, the same tab structure
should move from the desktop widget into the bar-click UI.

## Add This Source

Add the repository root as a Noctalia plugin source:

```text
https://github.com/devluixos/luixbits-noctalia-plugins
```

For local development, add the local path source instead:

```text
/home/luiz/projects/noctalia-plugins
```

Do not add a plugin subdirectory such as `casio-deck/` as a source. Noctalia
expects a source root containing one or more plugin directories.

## Repository Layout

```text
.
├── catalog.toml
├── docs/
├── scripts/
└── casio-deck/
    ├── plugin.toml
    ├── bridge.luau
    ├── helper/
    ├── examples/
    ├── dashboard.luau
    ├── qml/
    ├── status.luau
    ├── shortcut.luau
    ├── translations/
    └── assets/
```

## Development

Validate the source structure:

```sh
./scripts/validate.sh
```

Smoke-test the Casio Deck service after Noctalia has loaded and enabled it:

```sh
./scripts/smoke-casio-deck.sh
```

Run the experimental ABL-100WE helper manually:

```sh
./scripts/run-abl100-helper.sh --model abl100we --loop --debug
```
