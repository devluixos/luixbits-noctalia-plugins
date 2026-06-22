# Casio Deck Helper Protocol

`casio-deck` currently uses mock events through Noctalia IPC. The future watch
helper should emit a simple line protocol so the Noctalia plugin stays
hardware-agnostic.

Expected helper output:

```text
connect
press A
press B
press C
press D
disconnect
```

Rules:

- One event per line.
- Empty lines are ignored.
- `press <button>` should use stable logical button names, not raw device codes.
- The helper owns hardware-specific concerns such as Bluetooth, HID, serial,
  evdev, permissions, reconnects, and debouncing.
- The Noctalia service owns desktop-facing state and actions.

The bridge service can later consume the helper with `noctalia.runStream(...)`
and route each parsed line into the same command handler used by the current
mock IPC path.
