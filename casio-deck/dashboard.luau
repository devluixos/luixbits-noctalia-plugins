-- Casio Deck desktop setup widget.
--
-- This is the temporary Noctalia v5 UI until plugins can provide bar dropdown
-- panels. The bridge service owns the state; this widget renders tabs and sends
-- normalized commands back to the bridge.

local activeTab = "overview"

-- Status snapshot mirrored from the bridge service.
local current = {
  connected = false,
  connection_state = "manual",
  helper_configured = false,
  helper_ready = false,
  helper_started = false,
  paired = false,
  paired_at = "",
  watch_model = "casio_abl100we_3565",
  watch_model_name = "Casio ABL-100WE-1A",
  watch_model_module = "",
  watch_model_support = "supported",
  watch_name = "",
  watch_address = "",
  available_triggers = { "lower_right", "finder", "lower_left" },
  configured_presets = {},
  action_overrides = {},
  trigger_counts = {},
  connection_log = {},
  last_trace = "",
  trace_count = 0,
  last_raw = "",
  raw_count = 0,
  last_trigger = "",
  last_button = "",
  last_action = "idle",
  last_action_detail = "",
  last_source = "",
  last_error = "",
  press_count = 0,
  updated_at = "",
}

local function nowTime()
  return noctalia.formatTime("%H:%M:%S")
end

local function trim(value)
  local text = tostring(value or "")
  local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
  return trimmed
end

local function splitText(text, separator)
  local result = {}
  local start = 1

  while true do
    local nextIndex = string.find(text, separator, start, true)
    if nextIndex == nil then
      table.insert(result, string.sub(text, start))
      break
    end
    table.insert(result, string.sub(text, start, nextIndex - 1))
    start = nextIndex + string.len(separator)
  end

  return result
end

local function splitList(value)
  local result = {}
  for _, item in ipairs(splitText(tostring(value or ""), ",")) do
    local normalized = trim(item)
    if normalized ~= "" then
      table.insert(result, normalized)
    end
  end
  return result
end

local function parseDeckFields(parts, firstField)
  local fields = {}
  for index = firstField, #parts do
    local key, raw = string.match(parts[index], "^([^=]+)=(.*)$")
    if key ~= nil then
      if raw == "true" then
        fields[key] = true
      elseif raw == "false" then
        fields[key] = false
      else
        fields[key] = raw or ""
      end
    end
  end
  return fields
end

local function readDeckLines(path)
  local candidates = {
    path,
    "../../" .. path,
  }
  if type(noctalia.pluginDir) == "function" then
    table.insert(candidates, 1, noctalia.pluginDir() .. "/" .. path)
  end

  local lastError = ""
  local text = nil

  for _, candidate in ipairs(candidates) do
    local ok, result = pcall(function()
      return noctalia.readFile(candidate)
    end)
    if ok and type(result) == "string" and trim(result) ~= "" then
      text = result
      break
    end
    lastError = tostring(result)
  end

  if type(text) ~= "string" then
    error(`failed to read plugin data file: {path} ({lastError})`)
  end

  local lines = {}
  for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
    local cleaned = trim(line)
    if cleaned ~= "" and string.sub(cleaned, 1, 1) ~= "#" then
      table.insert(lines, cleaned)
    end
  end
  return lines
end

local function readModelsData(path)
  local data = { order = {}, models = {} }
  for _, line in ipairs(readDeckLines(path)) do
    local parts = splitText(line, "|")
    local kind = parts[1] or ""
    if kind == "order" then
      data.order = splitList(parts[2])
    elseif kind == "model" then
      local id = trim(parts[2])
      local model = parseDeckFields(parts, 3)
      model.id = id
      model.aliases = splitList(model.aliases)
      model.triggers = splitList(model.triggers)
      model.capabilities = splitList(model.capabilities)
      data.models[id] = model
    end
  end
  return data
end

local function readActionsData(path)
  local data = {
    preset_order = {},
    presets = {},
    trigger_order = {},
    triggers = {},
  }

  for _, line in ipairs(readDeckLines(path)) do
    local parts = splitText(line, "|")
    local kind = parts[1] or ""
    if kind == "preset_order" then
      data.preset_order = splitList(parts[2])
    elseif kind == "preset" then
      local id = trim(parts[2])
      data.presets[id] = parseDeckFields(parts, 3)
    elseif kind == "trigger_order" then
      data.trigger_order = splitList(parts[2])
    elseif kind == "trigger" then
      local id = trim(parts[2])
      data.triggers[id] = parseDeckFields(parts, 3)
    end
  end

  return data
end

-- Static model/action metadata shared with the bridge.
local modelData = readModelsData("data/models.deck")
local actionData = readActionsData("data/actions.deck")

local modelRows = {}
for _, id in ipairs(modelData.order or {}) do
  local model = (modelData.models or {})[id]
  if type(model) == "table" then
    table.insert(modelRows, {
      id = model.id,
      name = model.display_name,
      support = model.support,
      module = model.module,
      triggers = model.summary,
    })
  end
end

local triggerMeta = actionData.triggers or {}
local presetOrder = actionData.preset_order or {}
local presetLabels = {}
for id, preset in pairs(actionData.presets or {}) do
  presetLabels[id] = preset.short_label or preset.label or id
end

local function configString(key)
  local value = desktopWidget.getConfig(key)
  if type(value) ~= "string" then
    return ""
  end
  return trim(value)
end

local function value(text, fallback)
  text = trim(text)
  if text == "" then
    return fallback or "-"
  end
  return text
end

local function tableHasItems(value)
  return type(value) == "table" and #value > 0
end

local widgetWidth = 520
local widgetHeight = 384
local contentWidth = 500
local contentInnerWidth = contentWidth - 16

local render

-- Bridge command helper. It optimistically updates local UI state, then sends
-- the normalized command through noctalia.state for the bridge to process.
local function send(action, payload)
  current.last_source = "dashboard"
  current.last_action = action
  current.last_action_detail = trim(payload)
  current.updated_at = nowTime()

  if action == "select_model" then
    current.watch_model = trim(payload)
    local model = (modelData.models or {})[current.watch_model]
    if type(model) == "table" then
      current.watch_model_name = model.display_name
      current.watch_model_support = model.support
      current.watch_model_module = model.module
      current.available_triggers = model.triggers or {}
    end
  elseif action == "start_helper" then
    current.connection_state = "starting"
    current.helper_started = true
  elseif action == "stop_helper" then
    current.connection_state = "stopped"
    current.helper_started = false
    current.helper_ready = false
    current.connected = false
  elseif action == "setup_pairing" then
    current.connection_state = "setup_pairing"
    current.last_action_detail = "pair/setup requested"
  elseif action == "set_preset" then
    local trigger, preset = string.match(trim(payload), "^%s*([^=:%s]+)%s*[:=]%s*(.-)%s*$")
    trigger = trim(trigger)
    preset = trim(preset)
    if trigger ~= "" and preset ~= "" then
      current.action_overrides[trigger] = preset
      current.last_action_detail = trigger .. "=" .. preset
    end
  elseif action == "reset" then
    current.last_trigger = ""
    current.last_button = ""
    current.last_error = ""
    current.press_count = 0
    current.raw_count = 0
    current.last_raw = ""
    current.trace_count = 0
    current.last_trace = ""
    current.connection_log = {}
    current.trigger_counts = {}
  end

  if render ~= nil then
    render()
  end

  noctalia.state.set("command", {
    action = action,
    payload = payload,
    trigger = payload,
    source = "desktop-dashboard",
    focusedOutputName = noctalia.focusedOutputName(),
  })
end

local function modelIndexForId(modelId)
  for index, model in ipairs(modelRows) do
    if model.id == modelId then
      return index
    end
  end
  return 1
end

local function currentModelRow()
  return modelRows[modelIndexForId(current.watch_model)] or modelRows[1]
end

local function cycleWatchModel(delta)
  local index = modelIndexForId(current.watch_model) + delta
  while index < 1 do
    index += #modelRows
  end
  while index > #modelRows do
    index -= #modelRows
  end
  send("select_model", modelRows[index].id)
end

-- Shared UI primitives.
local function statLine(label, text, width)
  return ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
    ui.label({
      text = label,
      color = "on_surface_variant",
      fontSize = 11,
      maxWidth = width or 92,
      maxLines = 1,
    }),
    ui.label({
      text = value(text),
      color = "on_surface",
      fontSize = 11,
      fontWeight = "medium",
      maxWidth = 390,
      maxLines = 1,
    }),
  })
end

local function sectionTitle(text)
  return ui.label({
    text = text,
    color = "on_surface",
    fontSize = 13,
    fontWeight = "bold",
    maxLines = 1,
  })
end

local function muted(text, width)
  return ui.label({
    text = text,
    color = "on_surface_variant",
    fontSize = 11,
    maxWidth = width or 390,
    maxLines = 2,
  })
end

local function fillerLine(fontSize)
  return ui.label({
    text = " ",
    color = "surface",
    fontSize = fontSize or 10,
    maxWidth = contentWidth,
    maxLines = 1,
  })
end

local function padRows(rows, target, filler)
  while #rows < target do
    table.insert(rows, filler ~= nil and filler() or fillerLine())
  end
  return rows
end

local function tabButton(tab, label, callback)
  return ui.button({
    text = label,
    variant = activeTab == tab and "primary" or "outline",
    width = 94,
    fontSize = 11,
    onClick = callback,
  })
end

local function isListenerActive()
  local state = string.lower(trim(current.connection_state))
  return current.helper_started == true
    or current.helper_ready == true
    or state == "waiting"
    or state == "listening"
    or state == "connected"
    or state == "subscribed"
end

local function listenerStatusText()
  if current.connected then
    return "connected"
  end
  if isListenerActive() then
    return "listening"
  end
  if current.helper_configured then
    return "not listening"
  end
  return "not configured"
end

local function listenerStatusColor()
  if current.connected or isListenerActive() then
    return "primary"
  end
  return "on_surface_variant"
end

local function listenerButton()
  if isListenerActive() then
    return ui.button({
      text = "Stop listening",
      glyph = "player-stop",
      variant = "outline",
      onClick = "stopHelper",
    })
  end

  return ui.button({
    text = "Start listening",
    glyph = "player-play",
    variant = "primary",
    onClick = "startHelper",
  })
end

local function triggerList()
  if tableHasItems(current.available_triggers) then
    return current.available_triggers
  end

  local model = (modelData.models or {})[current.watch_model]
  if type(model) == "table" and type(model.triggers) == "table" then
    return model.triggers
  end

  return {}
end

local function currentPresetForTrigger(trigger)
  if type(current.action_overrides) == "table" then
    local override = current.action_overrides[trigger]
    if type(override) == "string" and override ~= "" then
      return override
    end
  end

  local meta = triggerMeta[trigger]
  if meta == nil then
    return "none"
  end

  if meta.preset == nil then
    return "none"
  end

  if type(current.configured_presets) == "table" then
    local configured = current.configured_presets[trigger]
    if type(configured) == "string" and configured ~= "" then
      return configured
    end
  end

  local preset = configString(meta.preset)
  if preset ~= "" and preset ~= "none" then
    return preset
  end

  return "none"
end

local function mappingForTrigger(trigger)
  local meta = triggerMeta[trigger]
  if meta == nil then
    return "not configurable yet"
  end

  local preset = currentPresetForTrigger(trigger)
  if preset ~= "" and preset ~= "none" then
    return presetLabels[preset] or preset
  end

  local mapText = configString("trigger_action_map")
  if mapText ~= "" then
    if string.find(mapText, trigger .. "=", 1, true) or string.find(mapText, trigger .. ":", 1, true) then
      return "advanced map"
    end
  end

  local command = meta.command ~= nil and configString(meta.command) or ""
  if command ~= "" then
    return "custom command"
  end

  return "not mapped"
end

local function presetIndex(preset)
  for index, candidate in ipairs(presetOrder) do
    if candidate == preset then
      return index
    end
  end
  return 1
end

local function setTriggerPreset(trigger, preset)
  if presetLabels[preset] == nil then
    preset = "none"
  end
  send("set_preset", trigger .. "=" .. preset)
end

local function cycleTriggerPreset(trigger, delta)
  local index = presetIndex(currentPresetForTrigger(trigger)) + delta
  while index < 1 do
    index += #presetOrder
  end
  while index > #presetOrder do
    index -= #presetOrder
  end
  setTriggerPreset(trigger, presetOrder[index])
end

local function triggerCount(trigger)
  if type(current.trigger_counts) ~= "table" then
    return 0
  end

  local count = current.trigger_counts[trigger]
  if type(count) == "number" then
    return count
  end
  if type(count) == "string" then
    return tonumber(count) or 0
  end
  return 0
end

-- Function tab rows.
local function triggerRow(trigger)
  local meta = triggerMeta[trigger] or { label = trigger, on_click = "statusDeck" }
  local support = meta.support or ""
  local count = triggerCount(trigger)
  local actionText = mappingForTrigger(trigger)
  local onClick = meta.on_click or meta.onClick or "statusDeck"
  return ui.column({
    gap = 3,
    minWidth = contentWidth,
  }, {
    ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
      ui.label({
        text = meta.label,
        color = "on_surface",
        fontSize = 13,
        fontWeight = "bold",
        maxWidth = 180,
        maxLines = 1,
      }),
      ui.label({
        text = actionText,
        color = "on_surface",
        fontSize = 12,
        fontWeight = "medium",
        maxWidth = 260,
        maxLines = 1,
      }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({
        text = tostring(count),
        color = count > 0 and "primary" or "on_surface_variant",
        fontSize = 10,
        fontWeight = "medium",
        maxWidth = 24,
        maxLines = 1,
      }),
    }),
    ui.row({ gap = 6, align = "center", minWidth = contentWidth }, {
      ui.label({
        text = value(support, "confirmed input"),
        color = "on_surface_variant",
        fontSize = 10,
        maxWidth = 350,
        maxLines = 1,
      }),
      ui.spacer({ flexGrow = 1 }),
      ui.button({
        text = "",
        glyph = "chevron-left",
        variant = "outline",
        onClick = "previousPreset_" .. trigger,
      }),
      ui.button({
        text = "",
        glyph = "chevron-right",
        variant = "outline",
        onClick = "nextPreset_" .. trigger,
      }),
      ui.button({
        text = "",
        glyph = "player-play",
        variant = "secondary",
        onClick = onClick,
      }),
    }),
    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
  })
end

local function triggerRows()
  local rows = {}
  for _, trigger in ipairs(triggerList()) do
    table.insert(rows, triggerRow(trigger))
  end
  if #rows == 0 then
    table.insert(rows, muted("No configurable triggers for this model yet. Add a helper adapter before assigning functions.", 560))
  end
  return rows
end

local function connectionLogRows(limit)
  local rows = {}
  local logRows = current.connection_log

  if not tableHasItems(logRows) then
    table.insert(rows, muted("No connection trace yet.", contentWidth))
    return padRows(rows, limit or 6)
  end

  local maxRows = #logRows
  local maxVisible = limit or 6
  if maxRows > maxVisible then
    maxRows = maxVisible
  end

  for index = 1, maxRows do
    table.insert(rows, ui.label({
      text = tostring(logRows[index]),
      color = "on_surface_variant",
      fontSize = 10,
      maxWidth = contentWidth,
      maxLines = 1,
    }))
  end

  return padRows(rows, maxVisible)
end

-- Tab renderers.
local function overviewTab()
  local sessionText = current.connected and "connected now" or "not connected now"
  local bondText = current.paired
    and ("saved" .. (current.paired_at ~= "" and (" at " .. current.paired_at) or ""))
    or "not verified"
  local watchText = value(current.watch_name, current.watch_model_name)
  local addressText = value(current.watch_address, "no address")

  return ui.column({ gap = 8 }, {
    sectionTitle("Overview"),
    ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
      ui.glyph({ name = "radio", size = 16, color = listenerStatusColor() }),
      ui.label({
        text = "Listener",
        color = "on_surface_variant",
        fontSize = 11,
        maxWidth = 70,
        maxLines = 1,
      }),
      ui.label({
        text = listenerStatusText(),
        color = listenerStatusColor(),
        fontSize = 12,
        fontWeight = "bold",
        maxWidth = 170,
        maxLines = 1,
      }),
    }),
    ui.column({ gap = 4 }, {
      statLine("Connection", current.connection_state .. " / " .. sessionText),
      statLine("Paired", bondText),
      statLine("Watch", watchText),
      statLine("Address", addressText),
      statLine("Last trigger", current.last_trigger),
      statLine("Last action", value(current.last_action) .. " / " .. value(current.last_action_detail)),
      statLine("Error", current.last_error),
      statLine("Presses", tostring(current.press_count)),
    }),
    ui.separator({ color = "outline", thickness = 1, spacing = 2 }),
    ui.row({ gap = 6, align = "center", minWidth = contentWidth }, {
      listenerButton(),
      ui.button({ text = "Pair", glyph = "bluetooth", variant = "outline", onClick = "setupPairing" }),
      ui.button({ text = "Reset", glyph = "rotate", variant = "outline", onClick = "resetDeck" }),
    }),
    muted("Updated " .. value(current.updated_at), 390),
  })
end

local function modelSelector()
  local model = currentModelRow()
  local selected = current.watch_model == model.id
  return ui.column({
    gap = 4,
    padding = 8,
    minWidth = contentWidth,
    fill = "surface_variant",
    radius = 6,
    border = selected and "primary" or "outline",
    borderWidth = 1,
  }, {
    ui.row({ gap = 7, align = "center", minWidth = contentInnerWidth }, {
      ui.glyph({
        name = "device-watch",
        size = 15,
        color = selected and "primary" or "on_surface_variant",
      }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({
          text = model.name,
          color = "on_surface",
          fontSize = 12,
          fontWeight = "bold",
          maxWidth = 340,
          maxLines = 1,
        }),
        ui.label({
          text = model.support .. " - module " .. value(model.module, "-"),
          color = model.support == "unsupported" and "error" or "on_surface_variant",
          fontSize = 10,
          maxWidth = 340,
          maxLines = 1,
        }),
      }),
      ui.button({ text = "", glyph = "chevron-left", variant = "outline", onClick = "previousWatchModel" }),
      ui.button({ text = "", glyph = "chevron-right", variant = "outline", onClick = "nextWatchModel" }),
    }),
    muted(model.triggers, 360),
  })
end

local function connectionTab()
  local selectedDevice = value(current.watch_name, "no saved watch")
  if current.watch_address ~= "" then
    selectedDevice = selectedDevice .. " / " .. current.watch_address
  end

  return ui.column({ gap = 8 }, {
    sectionTitle("Connection"),
    modelSelector(),
    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
    ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
      ui.glyph({ name = "radio", size = 16, color = listenerStatusColor() }),
      ui.label({
        text = "Listener",
        color = "on_surface_variant",
        fontSize = 11,
        maxWidth = 82,
        maxLines = 1,
      }),
      ui.label({
        text = listenerStatusText(),
        color = listenerStatusColor(),
        fontSize = 12,
        fontWeight = "bold",
        maxWidth = 180,
        maxLines = 1,
      }),
    }),
    statLine("Device", selectedDevice),
    statLine("State", current.connection_state),
    statLine("Paired", current.paired and "verified" or "not verified"),
    ui.row({ gap = 6, align = "center", minWidth = contentWidth }, {
      ui.button({ text = "Pair", glyph = "bluetooth", variant = "primary", onClick = "setupPairing" }),
      listenerButton(),
    }),
    muted("Pair once, then keep Listener active for watch actions.", contentWidth),
  })
end

local function logsTab()
  return ui.column({ gap = 8 }, {
    sectionTitle("Logs"),
    ui.column({ gap = 4, minWidth = contentWidth }, {
      statLine("State", current.connection_state),
      statLine("Trace", tostring(current.trace_count) .. " / " .. value(current.last_trace)),
      statLine("Raw", tostring(current.raw_count) .. " / " .. value(current.last_raw)),
      statLine("Error", current.last_error),
      statLine("Updated", current.updated_at),
    }),
    ui.row({ gap = 6, align = "center" }, {
      ui.button({ text = "Reset", glyph = "rotate", variant = "outline", onClick = "resetDeck" }),
      ui.button({ text = "Info", glyph = "info-circle", variant = "ghost", onClick = "statusDeck" }),
    }),
    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
    ui.column({ gap = 3 }, connectionLogRows(6)),
  })
end

local function functionsTab()
  return ui.column({ gap = 8 }, {
    sectionTitle("Functions"),
    ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
      ui.label({
        text = value(current.watch_model_name),
        color = "on_surface_variant",
        fontSize = 11,
        maxWidth = 300,
        maxLines = 1,
      }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({
        text = tostring(#triggerList()) .. " inputs",
        color = "on_surface_variant",
        fontSize = 11,
        maxWidth = 70,
        maxLines = 1,
      }),
    }),
    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
    ui.column({ gap = 5, minWidth = contentWidth }, triggerRows()),
  })
end

local function linkRow(label, icon, url, onClick)
  return ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
    ui.glyph({ name = icon, size = 17, color = "primary" }),
    ui.label({
      text = label,
      color = "on_surface",
      fontSize = 12,
      fontWeight = "bold",
      maxWidth = 70,
      maxLines = 1,
    }),
    ui.label({
      text = url,
      color = "on_surface_variant",
      fontSize = 10,
      maxWidth = 300,
      maxLines = 1,
    }),
    ui.spacer({ flexGrow = 1 }),
    ui.button({
      text = "Open",
      glyph = "external-link",
      variant = "outline",
      onClick = onClick,
    }),
  })
end

local function infoRow(label, valueText)
  return ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
    ui.label({
      text = label,
      color = "on_surface_variant",
      fontSize = 11,
      maxWidth = 70,
      maxLines = 1,
    }),
    ui.label({
      text = value(valueText),
      color = "on_surface",
      fontSize = 11,
      fontWeight = "medium",
      maxWidth = 360,
      maxLines = 1,
    }),
  })
end

local function optionalVideoRow(videoUrl)
  if trim(videoUrl) == "" then
    return ui.row({ gap = 8, align = "center", minWidth = contentWidth }, {
      ui.label({
        text = "Video",
        color = "on_surface_variant",
        fontSize = 11,
        maxWidth = 70,
        maxLines = 1,
      }),
      ui.label({
        text = "not set yet",
        color = "on_surface_variant",
        fontSize = 11,
        maxWidth = 360,
        maxLines = 1,
      }),
    })
  end

  return linkRow("Video", "movie", videoUrl, "openVideoLink")
end

local function aboutTab()
  local youtubeUrl = value(configString("youtube_channel_url"), "https://www.youtube.com/@LuixBits")
  local videoUrl = configString("explanation_video_url")
  local githubUrl = "https://github.com/devluixos/luixbits-noctalia-plugins"

  return ui.column({ gap = 7 }, {
    sectionTitle("About"),
    muted("Casio Deck turns supported Casio Bluetooth watch events into Noctalia actions.", contentWidth),
    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
    linkRow("GitHub", "brand-github", githubUrl, "openGitHubLink"),
    linkRow("YouTube", "brand-youtube", youtubeUrl, "openYouTubeLink"),
    optionalVideoRow(videoUrl),
    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
    infoRow("Support", "ABL-100WE 3565 experimental"),
    infoRow("Helper", "Python / bleak / gshock-api"),
  })
end

local function content()
  if activeTab == "connection" then
    return connectionTab()
  elseif activeTab == "logs" then
    return logsTab()
  elseif activeTab == "functions" then
    return functionsTab()
  elseif activeTab == "about" then
    return aboutTab()
  end
  return overviewTab()
end

render = function()
  local connectedColor = current.connected and "primary" or "on_surface_variant"
  local stateText = value(current.connection_state, current.connected and "connected" or "offline")
  local helperText = listenerStatusText()

  desktopWidget.render(ui.column({
    gap = 7,
    padding = 8,
    width = widgetWidth,
    height = widgetHeight,
    fill = "surface",
    radius = 8,
    border = "outline",
    borderWidth = 1,
  }, {
    ui.row({ gap = 6, align = "center", minWidth = contentWidth }, {
      tabButton("overview", "Overview", "showOverviewTab"),
      tabButton("connection", "Connection", "showConnectionTab"),
      tabButton("logs", "Logs", "showLogsTab"),
      tabButton("functions", "Functions", "showFunctionsTab"),
      tabButton("about", "About", "showAboutTab"),
    }),

    ui.row({ gap = 7, align = "center", minWidth = contentWidth }, {
      ui.glyph({ name = "device-watch", size = 17, color = connectedColor }),
      ui.label({
        text = "Casio Deck",
        fontSize = 13,
        fontWeight = "bold",
        color = "on_surface",
        maxLines = 1,
      }),
      ui.label({
        text = stateText .. " - " .. helperText,
        fontSize = 10,
        color = "on_surface_variant",
        maxLines = 1,
        maxWidth = 330,
      }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({
        text = "#" .. tostring(current.press_count),
        fontSize = 12,
        fontWeight = "bold",
        color = "primary",
      }),
    }),

    ui.separator({ color = "outline", thickness = 1, spacing = 1 }),
    content(),
  }))
end

-- Bridge status watcher.
local function applyStatus(status)
  if type(status) == "table" then
    current.connected = status.connected == true
    current.connection_state = status.connection_state or (current.connected and "connected" or "offline")
    current.helper_configured = status.helper_configured == true
    current.helper_ready = status.helper_ready == true
    current.helper_started = status.helper_started == true
    current.paired = status.paired == true
    current.paired_at = status.paired_at or ""
    current.watch_model = status.watch_model or "casio_abl100we_3565"
    current.watch_model_name = status.watch_model_name or current.watch_model
    current.watch_model_module = status.watch_model_module or ""
    current.watch_model_support = status.watch_model_support or ""
    current.watch_name = status.watch_name or ""
    current.watch_address = status.watch_address or ""
    current.available_triggers = status.available_triggers or current.available_triggers
    current.configured_presets = status.configured_presets or {}
    current.action_overrides = status.action_overrides or {}
    current.trigger_counts = status.trigger_counts or {}
    current.connection_log = status.connection_log or {}
    current.last_trace = status.last_trace or ""
    current.trace_count = status.trace_count or 0
    current.last_raw = status.last_raw or ""
    current.raw_count = status.raw_count or 0
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

-- UI callbacks.
local function setActiveTab(tab)
  activeTab = tab
  render()
end

function showOverviewTab()
  setActiveTab("overview")
end

function showConnectionTab()
  setActiveTab("connection")
end

function showLogsTab()
  setActiveTab("logs")
end

function showFunctionsTab()
  setActiveTab("functions")
end

function showAboutTab()
  setActiveTab("about")
end

function openGitHubLink()
  send("open_url", "github")
end

function openYouTubeLink()
  send("open_url", "youtube")
end

function openVideoLink()
  send("open_url", "video")
end

function previousWatchModel()
  cycleWatchModel(-1)
end

function nextWatchModel()
  cycleWatchModel(1)
end

function startHelper()
  send("start_helper")
end

function stopHelper()
  send("stop_helper")
end

function setupPairing()
  send("setup_pairing")
end

function resetDeck()
  send("reset")
end

function statusDeck()
  send("status")
end

function pressLowerLeft()
  send("press", "lower_left")
end

function pressLowerRight()
  send("press", "lower_right")
end

function pressFinder()
  send("press", "finder")
end

function previousPreset_lower_right()
  cycleTriggerPreset("lower_right", -1)
end

function nextPreset_lower_right()
  cycleTriggerPreset("lower_right", 1)
end

function previousPreset_finder()
  cycleTriggerPreset("finder", -1)
end

function nextPreset_finder()
  cycleTriggerPreset("finder", 1)
end

function previousPreset_lower_left()
  cycleTriggerPreset("lower_left", -1)
end

function nextPreset_lower_left()
  cycleTriggerPreset("lower_left", 1)
end

function onIpc(event, payload)
  if event == "tab" then
    local tab = string.lower(trim(payload))
    if tab == "overview" or tab == "connection" or tab == "logs" or tab == "functions" or tab == "about" then
      setActiveTab(tab)
    end
  elseif event == "press" then
    send("press", payload)
  else
    send(event, payload)
  end
end

applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
