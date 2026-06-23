# Casio Deck Noctalia Entries

These files are the Luau entry scripts referenced by `plugin.toml`.

Each entry runs in its own Noctalia v5 Luau VM. Shared runtime state should move
through `noctalia.state`; shared static metadata lives in `../data/*.deck`.
Avoid direct Lua/Luau module imports unless Noctalia documents stable
sibling-module support.

The desktop setup widget is the exception: `../dashboard.luau` stays at plugin
root because the current Noctalia desktop-widget loader watches/loads that root
path.

## Entries

- `service/bridge.luau`: background service. It is the plugin brain: helper
  process lifecycle, helper protocol parsing, selected watch model, connection
  state, trigger validation, action mapping, notifications, and shell command
  execution.
- `widgets/status.luau`: top bar widget. It shows compact Casio Deck state and
  forwards click/IPC events to the bridge.
- `shortcuts/shortcut.luau`: small control-center shortcut. It forwards quick
  actions to the bridge.

## Data Flow

```text
Python helper or IPC test command
  -> service/bridge.luau
  -> noctalia.state.status / noctalia.state.event
  -> widgets/status.luau, ../dashboard.luau, shortcuts/shortcut.luau

status/dashboard/shortcut/IPC command
  -> noctalia.state.command
  -> service/bridge.luau
```
