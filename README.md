# LuixBits Noctalia Plugins

A collection of Noctalia v5 plugins by LuixBits.

The first plugin is `casio-deck`, a foundation for turning a Casio watch into a
stream-deck-like controller for a Wayland desktop.

If you like Linux desktop customization, NixOS, Wayland, and unusual input
device projects, I document builds like this on the LuixBits YouTube channel.

## Plugins

| Plugin | ID | Status |
| --- | --- | --- |
| Casio Deck | `luixbits/casio-deck` | Foundation / mock events |

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
