-- Casio Deck bar widget.
--
-- Left click is reserved for the future plugin dropdown panel. Noctalia v5's
-- Luau plugin API does not currently expose plugin-owned bar panels.
-- Right click reports the current bridge status. Middle click sends the first
-- trigger for quick local testing.
-- IPC can also target this widget and will forward commands to the bridge
-- service through noctalia.state.

local label = barWidget.getConfig("label") or "Casio"
local showLabel = barWidget.getConfig("show_label") ~= false
local showPressCount = barWidget.getConfig("show_press_count") ~= false
local hideDisconnected = barWidget.getConfig("hide_disconnected") == true

local current = {
  connected = false,
  connection_state = "manual",
  helper_configured = false,
  helper_ready = false,
  helper_started = false,
  helper_name = "",
  helper_version = "",
  helper_model = "",
  helper_capabilities = "",
  paired = false,
  paired_at = "",
  watch_model = "casio_abl100we_3565",
  watch_model_name = "Casio ABL-100WE-1A",
  watch_model_support = "supported",
  watch_name = "",
  watch_address = "",
  last_trigger = "",
  last_button = "",
  last_action = "idle",
  last_action_detail = "",
  last_source = "",
  last_error = "",
  press_count = 0,
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

  local trigger = current.last_trigger ~= "" and current.last_trigger or current.last_button

  if current.connected and trigger ~= "" then
    if showPressCount then
      return `{label} {trigger} #{current.press_count}`
    end
    return `{label} {trigger}`
  end

  if current.connected then
    return `{label} on`
  end

  if current.helper_started and current.connection_state ~= "" and current.connection_state ~= "manual" then
    return `{label} {current.connection_state}`
  end

  if current.paired then
    return `{label} paired`
  end

  if current.last_error ~= "" then
    return `{label} error`
  end

  if current.connection_state ~= "" and current.connection_state ~= "manual" then
    return `{label} {current.connection_state}`
  end

  if current.helper_ready then
    return `{label} ready`
  end

  if current.helper_configured then
    return `{label} wait`
  end

  return label
end

local function render()
  barWidget.setVisible(current.connected or current.paired or not hideDisconnected)

  if current.connected then
    barWidget.setGlyph("device-watch-check")
    barWidget.setGlyphColor("primary")
    barWidget.setColor("primary")
  elseif current.paired then
    barWidget.setGlyph("device-watch")
    barWidget.setGlyphColor("secondary")
    barWidget.setColor("secondary")
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
    { key = "State", value = current.connection_state ~= "" and current.connection_state or (current.connected and "connected" or "disconnected") },
    { key = "Live BLE session", value = current.connected and "connected now" or "not connected now" },
    { key = "Bond saved", value = current.paired and "yes" or "no" },
    { key = "Bond time", value = current.paired_at ~= "" and current.paired_at or "-" },
    { key = "Helper", value = current.helper_name ~= "" and current.helper_name or "-" },
    { key = "Helper ready", value = current.helper_ready and "yes" or "no" },
    { key = "Helper started", value = current.helper_started and "yes" or "no" },
    { key = "Helper version", value = current.helper_version ~= "" and current.helper_version or "-" },
    { key = "Helper model", value = current.helper_model ~= "" and current.helper_model or "-" },
    { key = "Helper caps", value = current.helper_capabilities ~= "" and current.helper_capabilities or "-" },
    { key = "Watch model", value = current.watch_model ~= "" and current.watch_model or "-" },
    { key = "Watch name/model", value = current.watch_model_name ~= "" and current.watch_model_name or "-" },
    { key = "Support", value = current.watch_model_support ~= "" and current.watch_model_support or "-" },
    { key = "Watch name", value = current.watch_name ~= "" and current.watch_name or "-" },
    { key = "Watch address", value = current.watch_address ~= "" and current.watch_address or "-" },
    { key = "Last trigger", value = current.last_trigger ~= "" and current.last_trigger or "-" },
    { key = "Last button", value = current.last_button ~= "" and current.last_button or "-" },
    { key = "Action", value = current.last_action },
    { key = "Action detail", value = current.last_action_detail ~= "" and current.last_action_detail or "-" },
    { key = "Source", value = current.last_source ~= "" and current.last_source or "-" },
    { key = "Last error", value = current.last_error ~= "" and current.last_error or "-" },
    { key = "Presses", value = tostring(current.press_count) },
    { key = "Updated", value = current.updated_at ~= "" and current.updated_at or "-" },
  })
end

local function applyStatus(status)
  if type(status) == "table" then
    current.connected = status.connected == true
    current.connection_state = status.connection_state or (current.connected and "connected" or "offline")
    current.helper_configured = status.helper_configured == true
    current.helper_ready = status.helper_ready == true
    current.helper_started = status.helper_started == true
    current.helper_name = status.helper_name or ""
    current.helper_version = status.helper_version or ""
    current.helper_model = status.helper_model or ""
    current.helper_capabilities = status.helper_capabilities or ""
    current.paired = status.paired == true
    current.paired_at = status.paired_at or ""
    current.watch_model = status.watch_model or "casio_abl100we_3565"
    current.watch_model_name = status.watch_model_name or current.watch_model
    current.watch_model_support = status.watch_model_support or ""
    current.watch_name = status.watch_name or ""
    current.watch_address = status.watch_address or ""
    current.last_trigger = status.last_trigger or ""
    current.last_button = status.last_button or ""
    current.last_action = status.last_action or "idle"
    current.last_action_detail = status.last_action_detail or ""
    current.last_source = status.last_source or ""
    current.last_error = status.last_error or ""
    current.press_count = status.press_count or 0
    current.updated_at = status.updated_at or ""
  end
  render()
end

function onClick()
  noctalia.notifyError("Casio Deck", "Bar dropdown panels are not exposed to v5 plugins yet. Use the Casio Deck desktop widget for setup.")
end

function onRightClick()
  send("status")
end

function onMiddleClick()
  send("press", "lower_right")
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
