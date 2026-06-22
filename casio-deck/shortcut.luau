-- Casio Deck control-center shortcut.
--
-- Left click connects if disconnected, otherwise sends mock button A.
-- Right click disconnects.

local current = {
  connected = false,
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
  if current.connected then
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
    current.last_button = status.last_button or ""
    current.press_count = status.press_count or 0
  end
  render()
end

function onClick()
  if current.connected then
    send("press", "A")
  else
    send("connect")
  end
end

function onRightClick()
  send("disconnect")
end

applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
