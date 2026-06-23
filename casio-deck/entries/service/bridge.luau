-- Casio Deck bridge service.
--
-- The service owns normalized plugin state, model capabilities, trigger-action
-- mappings, helper output parsing, and command execution. Bluetooth stays in
-- the external helper process.

-- Config and data loading.
local function trim(value)
  local text = tostring(value or "")
  local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
  return trimmed
end

local function configString(key)
  local value = noctalia.getConfig(key)
  if type(value) ~= "string" then
    return ""
  end
  return trim(value)
end

local function configSelect(key, fallback)
  local value = configString(key)
  if value == "" then
    return fallback
  end
  return value
end

local function configBool(key, fallback)
  local value = noctalia.getConfig(key)
  if type(value) == "boolean" then
    return value
  end
  if value == nil then
    return fallback
  end
  return value == true
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

local helperCommand = configString("helper_command")
local stopCommand = configString("stop_command")
local pairCommand = configString("pair_command")
local autostartHelper = configBool("autostart_helper", false)
local savedWatchName = configString("saved_watch_name")
local savedWatchAddress = configString("saved_watch_address")
local githubUrl = "https://github.com/devluixos/luixbits-noctalia-plugins"
local youtubeUrl = configSelect("youtube_channel_url", "https://www.youtube.com/@LuixBits")
local videoUrl = configString("explanation_video_url")

local notifyOnPress = noctalia.getConfig("notify_on_press")
if notifyOnPress == nil then
  notifyOnPress = true
end

local modelData = readModelsData("data/models.deck")
local actionData = readActionsData("data/actions.deck")

local models = modelData.models or {}
local modelAliases = {}

for _, model in pairs(models) do
  if type(model) == "table" and type(model.aliases) == "table" then
    for _, alias in ipairs(model.aliases) do
      modelAliases[alias] = model.id
    end
  end
end

local function normalizeModelId(value)
  local raw = string.lower(trim(value))
  raw = string.gsub(raw, "[%s%-]+", "_")
  if raw == "" then
    return "casio_abl100we_3565"
  end
  return modelAliases[raw] or raw
end

-- Model and action metadata.
local function modelForId(value)
  local id = normalizeModelId(value)
  return models[id] or models.casio_abl100we_3565
end

local selectedModelId = normalizeModelId(configString("watch_model"))
if models[selectedModelId] == nil then
  selectedModelId = "casio_abl100we_3565"
end

local actionPresets = actionData.presets or {}
local triggerDefinitions = actionData.triggers or {}

local function readTriggerCommandSettings()
  local commands = {}
  for trigger, meta in pairs(triggerDefinitions) do
    if type(meta) == "table" and type(meta.command) == "string" then
      commands[trigger] = configString(meta.command)
    end
  end
  return commands
end

local function readTriggerPresetSettings()
  local presets = {}
  for trigger, meta in pairs(triggerDefinitions) do
    if type(meta) == "table" and type(meta.preset) == "string" then
      presets[trigger] = configSelect(meta.preset, "none")
    end
  end
  return presets
end

local triggerCommands = readTriggerCommandSettings()
local triggerPresets = readTriggerPresetSettings()

local configurableTriggerOrder = actionData.trigger_order or {}
local triggerTestLabels = {}

for trigger, meta in pairs(triggerDefinitions) do
  triggerTestLabels[trigger] = meta.test_label or meta.label or trigger
end

local function normalizeTrigger(value)
  if type(value) == "table" then
    value = value.trigger or value.button or value.key or value.name or value[1]
  end

  local raw = trim(value)
  if raw == "" then
    return ""
  end

  local upper = string.upper(raw)
  if string.sub(upper, 1, 7) == "BUTTON_" then
    upper = string.sub(upper, 8)
    raw = string.sub(raw, 8)
  end

  if upper == "A" or upper == "B" or upper == "C" or upper == "D" then
    return upper
  end

  local trigger = string.lower(raw)
  trigger = string.gsub(trigger, "[%s%-]+", "_")
  return trigger
end

local function actionOverridePath()
  local ok, home = pcall(function()
    return os.getenv("HOME")
  end)
  if not ok or trim(home) == "" then
    return ""
  end
  return trim(home) .. "/.cache/casio-deck/action-map.txt"
end

-- Action override persistence.
local actionOverrideFile = actionOverridePath()
local actionPresetOverrides = {}

local function loadActionPresetOverrides()
  if actionOverrideFile == "" or io == nil then
    return
  end

  local ok = pcall(function()
    local file = io.open(actionOverrideFile, "r")
    if file == nil then
      return
    end

    for line in file:lines() do
      local key, preset = string.match(line, "^%s*([^=:%s]+)%s*[:=]%s*(.-)%s*$")
      key = normalizeTrigger(key)
      preset = trim(preset)
      if key ~= "" and actionPresets[preset] ~= nil then
        actionPresetOverrides[key] = preset
      end
    end

    file:close()
  end)

  if not ok then
    actionPresetOverrides = {}
  end
end

local function saveActionPresetOverrides()
  if actionOverrideFile == "" or io == nil then
    return false
  end

  local ok = pcall(function()
    local file = io.open(actionOverrideFile, "w")
    if file == nil then
      return
    end

    for _, trigger in ipairs(configurableTriggerOrder) do
      local preset = actionPresetOverrides[trigger]
      if preset ~= nil and preset ~= "" then
        file:write(trigger .. "=" .. preset .. "\n")
      end
    end

    file:close()
  end)

  return ok
end

loadActionPresetOverrides()

local function contains(list, value)
  if type(list) ~= "table" then
    return false
  end

  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end

  return false
end

-- Trigger support and action resolution helpers.
local function supportedBySelectedModel(trigger)
  local model = models[selectedModelId] or models.casio_abl100we_3565
  return contains(model.triggers, trigger)
end

local function configurableTriggerSupported(trigger)
  return supportedBySelectedModel(trigger)
end

local function parseActionMap(text)
  local actions = {}
  local raw = trim(text)
  if raw == "" then
    return actions
  end

  for entry in string.gmatch(raw, "[^\n;]+") do
    local key, spec = string.match(entry, "^%s*([^=:%s]+)%s*[:=]%s*(.-)%s*$")
    key = normalizeTrigger(key)
    spec = trim(spec)

    if key ~= "" and spec ~= "" then
      local kind, value = string.match(spec, "^(%w+)%s*:%s*(.*)$")
      kind = string.lower(trim(kind))
      value = trim(value)

      if kind == "preset" and actionPresets[value] ~= nil then
        actions[key] = { kind = "preset", value = value }
      elseif kind == "command" and value ~= "" then
        actions[key] = { kind = "command", value = value }
      elseif actionPresets[spec] ~= nil then
        actions[key] = { kind = "preset", value = spec }
      else
        actions[key] = { kind = "command", value = spec }
      end
    end
  end

  return actions
end

local actionMap = parseActionMap(configString("trigger_action_map"))
local triggerCounts = {}
local connectionLog = {}
local helperStarted = false

local selectedModel = modelForId(selectedModelId)

-- Published bridge status.
local status = {
  connected = false,
  connection_state = helperCommand ~= "" and (autostartHelper and "starting" or "idle") or "manual",
  helper_configured = helperCommand ~= "",
  helper_ready = false,
  helper_started = false,
  helper_name = "",
  helper_version = "",
  helper_model = "",
  helper_capabilities = "",
  paired = savedWatchAddress ~= "",
  paired_at = "",
  watch_model = selectedModel.id,
  watch_model_name = selectedModel.display_name,
  watch_model_module = selectedModel.module,
  watch_model_support = selectedModel.support,
  watch_name = savedWatchName,
  watch_address = savedWatchAddress,
  available_triggers = selectedModel.triggers,
  configured_presets = triggerPresets,
  action_overrides = actionPresetOverrides,
  trigger_counts = triggerCounts,
  connection_log = connectionLog,
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
  updated_at = noctalia.formatTime("%H:%M:%S"),
}

local function refreshModelStatus()
  local model = modelForId(selectedModelId)
  selectedModelId = model.id
  status.watch_model = model.id
  status.watch_model_name = model.display_name
  status.watch_model_module = model.module
  status.watch_model_support = model.support
  status.available_triggers = model.triggers
end

-- Publishing, errors, and diagnostics.
local function publish()
  refreshModelStatus()
  status.helper_started = helperStarted
  status.connection_log = connectionLog
  status.action_overrides = actionPresetOverrides
  status.configured_presets = triggerPresets
  status.updated_at = status.updated_at or noctalia.formatTime("%H:%M:%S")

  noctalia.state.set("status", {
    connected = status.connected,
    connection_state = status.connection_state,
    helper_configured = status.helper_configured,
    helper_ready = status.helper_ready,
    helper_started = status.helper_started,
    helper_name = status.helper_name,
    helper_version = status.helper_version,
    helper_model = status.helper_model,
    helper_capabilities = status.helper_capabilities,
    paired = status.paired,
    paired_at = status.paired_at,
    watch_model = status.watch_model,
    watch_model_name = status.watch_model_name,
    watch_model_module = status.watch_model_module,
    watch_model_support = status.watch_model_support,
    watch_name = status.watch_name,
    watch_address = status.watch_address,
    available_triggers = status.available_triggers,
    configured_presets = status.configured_presets,
    action_overrides = status.action_overrides,
    trigger_counts = status.trigger_counts,
    connection_log = status.connection_log,
    last_trace = status.last_trace,
    trace_count = status.trace_count,
    last_raw = status.last_raw,
    raw_count = status.raw_count,
    last_trigger = status.last_trigger,
    last_button = status.last_button,
    last_action = status.last_action,
    last_action_detail = status.last_action_detail,
    last_source = status.last_source,
    last_error = status.last_error,
    press_count = status.press_count,
    updated_at = status.updated_at,
  })
end

local function recordError(message, source)
  local text = trim(message)
  if text == "" then
    text = "unknown error"
  end

  status.last_error = text
  status.connection_state = "error"
  status.last_source = source or "unknown"
  status.last_action = "error"
  status.last_action_detail = text
  status.updated_at = noctalia.formatTime("%H:%M:%S")

  noctalia.log(`casio-deck: {text}`)
  publish()
end

local function appendConnectionLog(kind, message)
  local text = trim(message)
  if text == "" then
    return
  end

  local line = noctalia.formatTime("%H:%M:%S") .. " " .. trim(kind) .. " " .. text
  table.insert(connectionLog, 1, line)
  while #connectionLog > 16 do
    table.remove(connectionLog)
  end

  status.connection_log = connectionLog
  status.last_trace = text
  status.trace_count += 1
  status.last_source = "helper"
  status.last_action = "trace"
  status.last_action_detail = text
  status.updated_at = noctalia.formatTime("%H:%M:%S")
end

local function recordRaw(payload)
  local text = trim(payload)
  if text == "" then
    return
  end

  appendConnectionLog("raw", text)
  status.connected = true
  status.helper_ready = true
  status.connection_state = "connected"
  status.raw_count += 1
  status.last_raw = text
  status.last_source = "helper"
  status.last_action = "raw_event"
  status.last_action_detail = text
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function setModel(modelId, source)
  local normalized = normalizeModelId(modelId)
  if models[normalized] == nil then
    recordError(`unknown watch model: {trim(modelId)}`, source)
    return
  end

  selectedModelId = normalized
  status.last_source = source or "unknown"
  status.last_action = "select_model"
  status.last_action_detail = normalized
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function syncKnownModel(modelId)
  local normalized = normalizeModelId(modelId)
  if models[normalized] ~= nil then
    selectedModelId = normalized
    return true
  end
  return false
end

local function setWatch(model, name, address)
  local normalized = normalizeModelId(model)
  if trim(model) ~= "" and syncKnownModel(normalized) then
    status.helper_model = normalized
  elseif trim(model) ~= "" then
    status.helper_model = trim(model)
  end

  if trim(name) ~= "" then
    status.watch_name = trim(name)
  end
  if trim(address) ~= "" then
    status.watch_address = trim(address)
  end
  status.last_source = "helper"
  status.last_action = "watch"
  status.last_action_detail = trim(name) ~= "" and trim(name) or trim(model)
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

-- State mutation helpers.
local function setConnected(connected, source)
  status.connected = connected == true
  if source == "helper" then
    status.helper_ready = true
  end
  status.last_source = source or "unknown"
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  if status.connected then
    status.connection_state = source == "helper" and "connected" or "manual"
    status.last_action = "connected"
    status.last_action_detail = status.watch_name
  else
    if helperStarted and source == "helper" then
      status.connection_state = "waiting"
    else
      status.connection_state = "disconnected"
    end
    status.last_action = "disconnected"
    status.last_action_detail = ""
  end
  publish()
end

local function setConnectionState(state, source)
  local normalized = string.lower(trim(state))
  if normalized == "" then
    normalized = "unknown"
  end

  status.connection_state = normalized
  status.last_source = source or "helper"
  status.last_action = "state"
  status.last_action_detail = normalized
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  appendConnectionLog("state", normalized)

  if normalized == "connected"
    or normalized == "subscribed"
    or normalized == "init_complete"
    or normalized == "app_connected"
    or normalized == "ble_held"
  then
    status.connected = true
    status.helper_ready = true
  elseif normalized == "session_complete"
    or normalized == "action_complete"
    or normalized == "pairing_complete"
  then
    status.connected = false
    status.helper_ready = true
  elseif normalized == "waiting"
    or normalized == "listening"
    or normalized == "connecting"
    or normalized == "pairing"
    or normalized == "setup_pairing"
    or normalized == "repairing"
    or normalized == "monitoring"
    or normalized == "phone_probe"
    or normalized == "syncing"
    or normalized == "reconnecting"
    or normalized == "disconnected"
    or normalized == "app_handshake_failed"
    or normalized == "action_failed"
  then
    status.connected = false
    status.helper_ready = true
  elseif normalized == "stopped"
    or normalized == "idle"
  then
    status.connected = false
    status.helper_ready = false
    helperStarted = false
  end

  publish()
end

local function resolveAction(trigger)
  local overridePreset = actionPresetOverrides[trigger]
  if overridePreset ~= nil and overridePreset ~= "" then
    if actionPresets[overridePreset] ~= nil then
      return "preset", overridePreset
    end
    return "invalid_preset", overridePreset
  end

  local mapped = actionMap[trigger]
  if mapped ~= nil then
    return mapped.kind, mapped.value
  end

  local presetId = triggerPresets[trigger]
  if presetId ~= nil and presetId ~= "" and presetId ~= "none" then
    if actionPresets[presetId] ~= nil then
      return "preset", presetId
    end
    return "invalid_preset", presetId
  end

  local command = trim(triggerCommands[trigger])
  if command ~= "" then
    return "command", command
  end

  return "none", ""
end

local function actionLabel(kind, value)
  if kind == "preset" then
    local preset = actionPresets[value]
    if preset ~= nil then
      return `preset:{value}`
    end
    return `invalid_preset:{value}`
  elseif kind == "command" then
    return "command"
  elseif kind == "invalid_preset" then
    return `invalid_preset:{value}`
  end
  return "no_command"
end

-- Action execution.
local function runCommand(command, trigger, source)
  local shellCommand = trim(command)
  if shellCommand == "" then
    return true
  end

  local ok, err = pcall(function()
    noctalia.runAsync(shellCommand)
  end)

  if not ok then
    recordError(`failed to run command for trigger {trigger}: {tostring(err)}`, source or "action")
    return false
  end

  return true
end

local function shellQuote(value)
  return "'" .. string.gsub(tostring(value or ""), "'", "'\\''") .. "'"
end

local function safeHttpsUrl(url)
  local text = trim(url)
  if string.match(text, "^https://[^%s]+$") then
    return text
  end
  return ""
end

local function openKnownUrl(payload, source)
  local key = string.lower(trim(payload))
  local url = ""

  if key == "github" then
    url = githubUrl
  elseif key == "youtube" then
    url = youtubeUrl
  elseif key == "video" then
    url = videoUrl
  else
    recordError(`unknown link: {payload}`, source or "about")
    return
  end

  url = safeHttpsUrl(url)
  if url == "" then
    recordError(`link is not configured or not https: {key}`, source or "about")
    return
  end

  local ok, err = pcall(function()
    noctalia.runAsync("xdg-open " .. shellQuote(url))
  end)

  if not ok then
    recordError(`failed to open link {key}: {tostring(err)}`, source or "about")
    return
  end

  status.last_source = source or "about"
  status.last_action = "open_link"
  status.last_action_detail = key
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function incrementTriggerCount(trigger)
  triggerCounts[trigger] = (triggerCounts[trigger] or 0) + 1
  status.trigger_counts = triggerCounts
end

local function clearTriggerCounts()
  for trigger in pairs(triggerCounts) do
    triggerCounts[trigger] = nil
  end
  status.trigger_counts = triggerCounts
end

local function runAction(trigger, kind, value)
  if kind == "none" then
    return
  end

  if kind == "invalid_preset" then
    recordError(`invalid preset for trigger {trigger}: {value}`, "action")
    return
  end

  if kind == "command" then
    runCommand(value, trigger, "action")
    return
  end

  if kind == "preset" then
    local preset = actionPresets[value]
    if preset == nil then
      recordError(`unknown preset for trigger {trigger}: {value}`, "action")
      return
    end

    if preset.notify then
      noctalia.notify("Casio Deck", triggerTestLabels[trigger] or `Trigger {trigger}`)
      return
    end

    runCommand(preset.command, trigger, "action")
  end
end

local function press(trigger, source)
  source = source or "unknown"
  trigger = normalizeTrigger(trigger)
  if trigger == "" then
    recordError("empty trigger", source)
    return
  end

  if not configurableTriggerSupported(trigger) then
    recordError(`unsupported trigger for {selectedModelId}: {trigger}`, source)
    return
  end

  local kind, value = resolveAction(trigger)
  local label = actionLabel(kind, value)

  if source == "helper" then
    status.connected = true
    status.connection_state = "connected"
  elseif helperCommand == "" then
    status.connected = true
    status.connection_state = "manual"
  end

  status.last_trigger = trigger
  status.last_button = trigger
  status.last_action = label
  status.last_action_detail = value
  status.last_source = source
  status.press_count += 1
  incrementTriggerCount(trigger)
  status.updated_at = noctalia.formatTime("%H:%M:%S")

  noctalia.state.set("event", {
    trigger = status.last_trigger,
    button = status.last_button,
    action = status.last_action,
    action_detail = status.last_action_detail,
    source = status.last_source,
    count = status.press_count,
    watch_model = status.watch_model,
    watch_name = status.watch_name,
    watch_address = status.watch_address,
    updated_at = status.updated_at,
  })

  if notifyOnPress then
    noctalia.notify("Casio Deck", `Trigger {trigger}: {label}`)
  end

  runAction(trigger, kind, value)
  publish()
end

local function reset()
  status.connected = false
  status.connection_state = helperStarted and "waiting" or "idle"
  status.last_trigger = ""
  status.last_button = ""
  status.last_action = "idle"
  status.last_action_detail = ""
  status.last_source = ""
  status.last_error = ""
  status.press_count = 0
  status.raw_count = 0
  status.last_raw = ""
  status.trace_count = 0
  status.last_trace = ""
  for index = #connectionLog, 1, -1 do
    table.remove(connectionLog, index)
  end
  status.connection_log = connectionLog
  clearTriggerCounts()
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

-- Helper protocol parsing.
local function setHelperReady(payload)
  local name, version, model = string.match(payload, "^(%S+)%s+(%S+)%s*(.*)$")
  local normalized = normalizeModelId(model)
  if models[normalized] ~= nil then
    selectedModelId = normalized
  end

  status.helper_ready = true
  if status.connection_state == "starting" or status.connection_state == "manual" then
    status.connection_state = "waiting"
  end
  status.helper_name = trim(name)
  status.helper_version = trim(version)
  status.helper_model = models[normalized] ~= nil and normalized or trim(model)
  status.last_source = "helper"
  status.last_action = "ready"
  status.last_action_detail = status.helper_model
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function isHelperDiagnosticLine(text)
  local lower = string.lower(trim(text))
  return string.sub(lower, 1, 17) == "writing to handle"
    or string.find(lower, "gshock_api.logger", 1, true) ~= nil
end

local function handleHelperLine(line)
  local text = trim(line)
  if text == "" then
    return
  end

  if isHelperDiagnosticLine(text) then
    noctalia.log(`casio-deck helper diagnostic: {text}`)
    return
  end

  local action, payload = string.match(text, "^(%S+)%s*(.*)$")
  action = string.lower(trim(action))
  payload = trim(payload)

  if action == "ready" then
    setHelperReady(payload)
  elseif action == "state" then
    setConnectionState(payload, "helper")
  elseif action == "model" then
    local model = string.match(payload, "^(%S+)")
    if model ~= nil then
      syncKnownModel(model)
    end
    status.helper_model = payload
    status.last_source = "helper"
    status.last_action = "model"
    status.last_action_detail = payload
    status.updated_at = noctalia.formatTime("%H:%M:%S")
    publish()
  elseif action == "capabilities" then
    status.helper_capabilities = payload
    status.last_source = "helper"
    status.last_action = "capabilities"
    status.last_action_detail = payload
    status.updated_at = noctalia.formatTime("%H:%M:%S")
    publish()
  elseif action == "trace" then
    appendConnectionLog("trace", payload)
    publish()
  elseif action == "watch" then
    local model, name, address = string.match(payload, "^(%S+)%s+(.+)%s+(%S+)$")
    if model == nil then
      model = payload
      name = ""
      address = ""
    end
    setWatch(model, name, address)
  elseif action == "paired" then
    local model, name, address = string.match(payload, "^(%S+)%s+(.+)%s+(%S+)$")
    if model == nil then
      model = payload
      name = ""
      address = ""
    end
    setWatch(model, name, address)
    status.paired = true
    status.paired_at = noctalia.formatTime("%H:%M:%S")
    status.connected = false
    status.helper_ready = true
    status.connection_state = "pairing_complete"
    status.last_source = "helper"
    status.last_action = "paired"
    status.last_action_detail = trim(address) ~= "" and trim(address) or trim(name)
    status.updated_at = noctalia.formatTime("%H:%M:%S")
    publish()
  elseif action == "connect" or action == "disconnect" then
    if action == "connect" then
      setConnected(true, "helper")
    else
      setConnected(false, "helper")
    end
  elseif action == "press" then
    local trigger = normalizeTrigger(payload)
    if supportedBySelectedModel(trigger) then
      press(trigger, "helper")
    else
      recordError(`invalid helper trigger for {selectedModelId}: {payload ~= "" and payload or "-"}`, "helper")
    end
  elseif action == "raw" then
    recordRaw(payload)
  elseif action == "error" then
    recordError(payload ~= "" and payload or "helper reported an error", "helper")
  else
    recordError(`invalid helper line: {text}`, "helper")
  end
end

-- Helper process and runtime commands.
local function startHelper(source)
  if helperCommand == "" then
    recordError("helper_command is empty; configure a helper command first", source or "helper")
    return
  end

  if helperStarted then
    status.last_source = source or "helper"
    status.last_action = "helper_already_started"
    status.last_action_detail = helperCommand
    status.updated_at = noctalia.formatTime("%H:%M:%S")
    publish()
    return
  end

  helperStarted = true
  status.helper_configured = true
  status.connection_state = "starting"
  status.last_source = source or "helper"
  status.last_action = "start_helper"
  status.last_action_detail = helperCommand
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()

  local ok, err = pcall(function()
    noctalia.runStream(helperCommand, handleHelperLine)
  end)

  if not ok then
    helperStarted = false
    recordError(`failed to start helper: {tostring(err)}`, source or "helper")
  end
end

local function stopHelper(source)
  if helperCommand == "" then
    setConnected(false, source or "helper")
    return
  end

  if stopCommand == "" then
    recordError("stop_command is empty; configure it to stop the listener from the dashboard", source or "helper")
    return
  end

  status.helper_configured = true
  status.connection_state = "stopping"
  status.last_source = source or "helper"
  status.last_action = "stop_helper"
  status.last_action_detail = stopCommand
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()

  local ok, err = pcall(function()
    noctalia.runAsync(stopCommand)
  end)

  if not ok then
    recordError(`failed to stop helper: {tostring(err)}`, source or "helper")
    return
  end

  helperStarted = false
  status.connected = false
  status.helper_ready = false
  status.connection_state = "stopped"
  status.last_source = source or "helper"
  status.last_action = "stop_helper"
  status.last_action_detail = "listener stop requested"
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function startPairSetup(source)
  if pairCommand == "" then
    status.last_source = source or "pair"
    status.last_action = "pair_requested"
    status.last_action_detail = "pair_command is empty; configure it before using Pair/Setup"
    status.updated_at = noctalia.formatTime("%H:%M:%S")
    publish()
    return
  end

  if helperStarted then
    recordError("cannot run Pair/Setup while the helper stream is running; reload the plugin first", source or "pair")
    return
  end

  status.last_source = source or "pair"
  status.last_action = "pair_started"
  status.last_action_detail = pairCommand
  status.connection_state = "setup_pairing"
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()

  local ok, err = pcall(function()
    noctalia.runStream(pairCommand, handleHelperLine)
  end)

  if not ok then
    recordError(`failed to start pair command: {tostring(err)}`, source or "pair")
  end
end

local function setPresetMapping(payload, source)
  local trigger, preset = string.match(trim(payload), "^%s*([^=:%s]+)%s*[:=]%s*(.-)%s*$")
  trigger = normalizeTrigger(trigger)
  preset = trim(preset)

  if trigger == "" then
    recordError("missing trigger for preset mapping", source or "mapping")
    return
  end

  if not configurableTriggerSupported(trigger) then
    recordError(`unsupported configurable trigger: {trigger}`, source or "mapping")
    return
  end

  if actionPresets[preset] == nil then
    recordError(`unknown preset for {trigger}: {preset}`, source or "mapping")
    return
  end

  actionPresetOverrides[trigger] = preset
  saveActionPresetOverrides()

  status.last_source = source or "mapping"
  status.last_action = "set_preset"
  status.last_action_detail = trigger .. "=" .. preset
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function handleCommand(action, payload, source)
  action = string.lower(trim(action))

  if action == "connect" then
    if helperCommand ~= "" then
      startHelper(source)
    else
      setConnected(true, source)
    end
  elseif action == "disconnect" then
    if helperCommand ~= "" then
      status.last_source = source or "helper"
      status.last_action = "disconnect_unsupported"
      status.last_action_detail = "helper mode requires plugin reload to stop the stream"
      status.updated_at = noctalia.formatTime("%H:%M:%S")
      publish()
    else
      setConnected(false, source)
    end
  elseif action == "toggle" then
    if helperCommand ~= "" then
      startHelper(source)
    else
      setConnected(not status.connected, source)
    end
  elseif action == "press" then
    press(payload, source)
  elseif action == "select_model" then
    setModel(payload, source)
  elseif action == "set_preset" or action == "map_preset" then
    setPresetMapping(payload, source)
  elseif action == "open_url" or action == "open_link" then
    openKnownUrl(payload, source)
  elseif action == "start_helper" then
    startHelper(source)
  elseif action == "stop_helper" then
    stopHelper(source)
  elseif action == "setup_pairing" or action == "pair_setup" or action == "pair" then
    startPairSetup(source)
  elseif action == "error" then
    recordError(payload, source)
  elseif action == "reset" then
    reset()
  elseif action == "status" then
    noctalia.notify(
      "Casio Deck",
      `model={status.watch_model} paired={tostring(status.paired)} connected={tostring(status.connected)} trigger={status.last_trigger} count={status.press_count} error={status.last_error}`
    )
  else
    local trigger = normalizeTrigger(action)
    if supportedBySelectedModel(trigger) then
      press(trigger, source)
    else
      recordError(`unknown command: {action}`, source)
    end
  end
end

noctalia.state.watch("command", function(command)
  if type(command) == "table" then
    local action = command.action or command.command
    local payload = command.trigger or command.button or command.payload or command.value or command.model
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

if helperCommand ~= "" and autostartHelper then
  startHelper("init")
end

publish()
