# Casio Deck QML UI

This directory is a temporary QML plugin UI for local development. It exists
because the current Noctalia v5 Luau plugin API does not expose the
Clipboard/System-style clicked panel surface yet.

The QML track gives us:

- a real bar item
- left-click panel opening through `pluginApi.openPanel(...)`
- tabs for Overview, Watch, Functions, and Settings
- local mock trigger buttons
- optional helper command start/stop controls

The v5 Luau plugin in `../plugin.toml`, `../bridge.luau`, and friends remains
the long-term portable plugin foundation. The Python helper under `../helper/`
is still the Bluetooth/GShockAPI experiment for the ABL-100WE.

Install locally with:

```sh
/home/luiz/projects/noctalia-plugins/scripts/install-qml-casio-deck.sh
```

That creates this symlink:

```text
/home/luiz/.config/noctalia/plugins/casio-deck -> /home/luiz/projects/noctalia-plugins/casio-deck/qml
```
