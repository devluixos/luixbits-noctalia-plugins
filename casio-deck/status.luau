-- Casio Deck bar widget.
--
-- Left click sends mock button A, right click sends B, middle click sends C.
-- IPC can also target this widget and will forward commands to the bridge
-- service through noctalia.state.

local label = barWidget.getConfig("label") or "Casio"
local showLabel = barWidget.getConfig("show_label") ~= false
local showPressCount = barWidget.getConfig("show_press_count") ~= false
local hideDisconnected = barWidget.getConfig("hide_disconnected") == true

local current = {
  connected = false,
  mode = "mock",
  helper_configured = false,
  last_button = "",
  last_action = "idle",
  last_source = "",
  press_count = 0,
  heartbeat = 0,
  updated_at = "",
}

local function send(action, button)
  noctalia.state.set("command", {
    action = action,
    button = button,
    source = "bar",
    focusedOutputName = noctalia.focusedOutputName(),
  })
end

local function textForStatus()
  if not showLabel then
    return ""
  end

  if current.connected and current.last_button ~= "" then
    if showPressCount then
      return `{label} {current.last_button} #{current.press_count}`
    end
    return `{label} {current.last_button}`
  end

  return label
end

local function render()
  barWidget.setVisible(current.connected or not hideDisconnected)

  if current.connected then
    barWidget.setGlyph("device-watch-check")
    barWidget.setGlyphColor("primary")
    barWidget.setColor("primary")
  elseif current.helper_configured then
    barWidget.setGlyph("device-watch-code")
    barWidget.setGlyphColor("secondary")
    barWidget.setColor("secondary")
  else
    barWidget.setGlyph("device-watch-off")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setColor("on_surface_variant")
  end

  barWidget.setText(textForStatus())
  barWidget.setTooltip({
    { key = "State", value = current.connected and "connected" or "disconnected" },
    { key = "Mode", value = current.mode },
    { key = "Last button", value = current.last_button ~= "" and current.last_button or "-" },
    { key = "Action", value = current.last_action },
    { key = "Source", value = current.last_source ~= "" and current.last_source or "-" },
    { key = "Presses", value = tostring(current.press_count) },
    { key = "Updated", value = current.updated_at ~= "" and current.updated_at or "-" },
  })
end

local function applyStatus(status)
  if type(status) == "table" then
    current.connected = status.connected == true
    current.mode = status.mode or "mock"
    current.helper_configured = status.helper_configured == true
    current.last_button = status.last_button or ""
    current.last_action = status.last_action or "idle"
    current.last_source = status.last_source or ""
    current.press_count = status.press_count or 0
    current.heartbeat = status.heartbeat or 0
    current.updated_at = status.updated_at or ""
  end
  render()
end

function onClick()
  send("press", "A")
end

function onRightClick()
  send("press", "B")
end

function onMiddleClick()
  send("press", "C")
end

function onIpc(event, payload)
  if event == "press" then
    send("press", payload)
  else
    send(event, payload)
  end
end

applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
