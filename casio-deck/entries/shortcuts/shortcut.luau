-- Casio Deck control-center shortcut.
--
-- In helper mode, left click starts/reports the helper and right
-- click reports status; it does not fake Bluetooth connection state.

local current = {
  connected = false,
  connection_state = "manual",
  helper_configured = false,
  helper_started = false,
  helper_ready = false,
  last_button = "",
  press_count = 0,
}

local function send(action, button)
  noctalia.state.set("command", {
    action = action,
    button = button,
    source = "shortcut",
    focusedOutputName = noctalia.focusedOutputName(),
  })
end

local function render()
  if current.helper_configured and not current.connected then
    shortcut.setLabel(`Casio {current.connection_state}`)
  elseif current.connected then
    local suffix = current.last_button ~= "" and ` {current.last_button}` or ""
    shortcut.setLabel(`Casio{suffix}`)
  else
    shortcut.setLabel("Casio Deck")
  end

  shortcut.setIcon("device-watch-check", "device-watch-off")
  shortcut.setActive(current.connected)
  shortcut.setEnabled(true)
end

local function applyStatus(status)
  if type(status) == "table" then
    current.connected = status.connected == true
    current.connection_state = status.connection_state or (current.connected and "connected" or "offline")
    current.helper_configured = status.helper_configured == true
    current.helper_started = status.helper_started == true
    current.helper_ready = status.helper_ready == true
    current.last_button = status.last_button or ""
    current.press_count = status.press_count or 0
  end
  render()
end

function onClick()
  if current.helper_configured then
    if current.helper_started then
      send("status")
    else
      send("start_helper")
    end
  elseif current.connected then
    send("press", "lower_right")
  else
    send("connect")
  end
end

function onRightClick()
  if current.helper_configured then
    send("status")
  else
    send("disconnect")
  end
end

applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
