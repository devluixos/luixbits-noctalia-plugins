-- Casio Deck headless service.
--
-- This is intentionally hardware-agnostic. It owns shared state and accepts
-- commands from the bar widget, control-center shortcut, IPC, or a future watch
-- helper process. The later helper can replace the mock "press" events without
-- changing the UI entries.

local helperCommand = noctalia.getConfig("helper_command") or ""
local notifyOnPress = noctalia.getConfig("notify_on_press")
if notifyOnPress == nil then
  notifyOnPress = true
end

local buttonActions = {
  A = "primary",
  B = "secondary",
  C = "tertiary",
  D = "utility",
}

local status = {
  connected = false,
  mode = "mock",
  helper_configured = helperCommand ~= "",
  last_button = "",
  last_action = "idle",
  last_source = "",
  press_count = 0,
  heartbeat = 0,
  updated_at = noctalia.formatTime("%H:%M:%S"),
}

local function trim(value)
  local text = tostring(value or "")
  local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
  return trimmed
end

local function normalizeButton(value)
  if type(value) == "table" then
    value = value.button or value.key or value.name or value[1]
  end

  local text = string.upper(trim(value))
  if string.sub(text, 1, 7) == "BUTTON_" then
    text = string.sub(text, 8)
  end
  return text
end

local function publish()
  noctalia.state.set("status", {
    connected = status.connected,
    mode = status.mode,
    helper_configured = status.helper_configured,
    last_button = status.last_button,
    last_action = status.last_action,
    last_source = status.last_source,
    press_count = status.press_count,
    heartbeat = status.heartbeat,
    updated_at = status.updated_at,
  })
end

local function setConnected(connected, source)
  status.connected = connected == true
  status.last_source = source or "unknown"
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  if status.connected then
    status.last_action = "connected"
  else
    status.last_action = "disconnected"
  end
  publish()
end

local function press(button, source)
  button = normalizeButton(button)
  if button == "" then
    return
  end

  status.connected = true
  status.last_button = button
  status.last_action = buttonActions[button] or "unmapped"
  status.last_source = source or "unknown"
  status.press_count += 1
  status.updated_at = noctalia.formatTime("%H:%M:%S")

  noctalia.state.set("event", {
    button = status.last_button,
    action = status.last_action,
    source = status.last_source,
    count = status.press_count,
    updated_at = status.updated_at,
  })

  if notifyOnPress then
    noctalia.notify("Casio Deck", `Button {button}: {status.last_action}`)
  end

  publish()
end

local function reset()
  status.connected = false
  status.last_button = ""
  status.last_action = "idle"
  status.last_source = ""
  status.press_count = 0
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function handleCommand(action, payload, source)
  action = string.lower(trim(action))

  if action == "connect" then
    setConnected(true, source)
  elseif action == "disconnect" then
    setConnected(false, source)
  elseif action == "toggle" then
    setConnected(not status.connected, source)
  elseif action == "press" then
    press(payload, source)
  elseif action == "reset" then
    reset()
  elseif action == "status" then
    noctalia.notify(
      "Casio Deck",
      `connected={tostring(status.connected)} button={status.last_button} count={status.press_count}`
    )
  else
    local button = normalizeButton(action)
    if button ~= "" and #button <= 12 then
      press(button, source)
    else
      noctalia.log(`casio-deck: unknown command '{action}'`)
    end
  end
end

noctalia.state.watch("command", function(command)
  if type(command) == "table" then
    local action = command.action or command.command
    local payload = command.button or command.payload or command.value
    if type(action) == "string" then
      handleCommand(action, payload, command.source or "state")
    end
  elseif type(command) == "string" then
    handleCommand(command, nil, "state")
  end
end)

function onIpc(event, payload)
  handleCommand(event, payload, "ipc")
end

noctalia.setUpdateInterval(5000)

function update()
  status.heartbeat += 1
  publish()
end

publish()
