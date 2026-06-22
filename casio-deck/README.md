# Casio Deck

Noctalia v5 plugin foundation for using a Casio watch as a stream-deck-like
controller.

This version does not talk to the watch yet. It provides the plugin structure,
bar widget, background service, control-center shortcut, local source catalog,
mock button events, and IPC commands.

## Layout

```text
/home/luiz/projects/noctalia-plugins/
  catalog.toml
  casio-deck/
    plugin.toml
    bridge.luau
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

In this NixOS/Home Manager setup, the same wiring lives in
`home/modules/niri/noctalia/default.nix`.

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

## Next Hardware Step

Once the watch protocol is known, add a helper process that emits normalized
lines such as:

```text
press A
press B
connect
disconnect
```

Then `bridge.luau` can run that helper with `noctalia.runStream(...)` and feed
the same command handler that the mock IPC path uses today.
