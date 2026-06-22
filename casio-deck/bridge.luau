-- Casio Deck bridge service.
--
-- The service owns normalized plugin state, model capabilities, trigger-action
-- mappings, helper output parsing, and command execution. Bluetooth stays in
-- the external helper process.

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

local helperCommand = configString("helper_command")
local scanCommand = configString("scan_command")

local notifyOnPress = noctalia.getConfig("notify_on_press")
if notifyOnPress == nil then
  notifyOnPress = true
end

local modelOrder = {
  "generic_abcd",
  "casio_abl100we_3565",
  "future_casio_ble",
}

local models = {
  generic_abcd = {
    id = "generic_abcd",
    display_name = "Generic A/B/C/D",
    module = "",
    support = "supported",
    adapter = "mock",
    triggers = { "A", "B", "C", "D" },
    capabilities = { "mock_events", "manual_testing" },
  },
  casio_abl100we_3565 = {
    id = "casio_abl100we_3565",
    display_name = "Casio ABL-100WE-1A",
    module = "3565",
    support = "experimental",
    adapter = "gshock-api",
    triggers = { "lower_left", "lower_right", "timeplace", "finder", "unknown" },
    capabilities = { "ble_connection", "button_events", "timeplace", "finder" },
  },
  future_casio_ble = {
    id = "future_casio_ble",
    display_name = "Other Casio Bluetooth watch",
    module = "",
    support = "unsupported",
    adapter = "",
    triggers = {},
    capabilities = { "planned_adapter" },
  },
}

local modelAliases = {
  abl100we = "casio_abl100we_3565",
  abl100 = "casio_abl100we_3565",
  casio_abl100we = "casio_abl100we_3565",
  module_3565 = "casio_abl100we_3565",
  generic = "generic_abcd",
  abcd = "generic_abcd",
}

local function normalizeModelId(value)
  local raw = string.lower(trim(value))
  raw = string.gsub(raw, "[%s%-]+", "_")
  if raw == "" then
    return "generic_abcd"
  end
  return modelAliases[raw] or raw
end

local function modelForId(value)
  local id = normalizeModelId(value)
  return models[id] or models.generic_abcd
end

local selectedModelId = normalizeModelId(configString("watch_model"))
if models[selectedModelId] == nil then
  selectedModelId = "generic_abcd"
end

local actionPresets = {
  none = {
    label = "Do nothing",
    command = "",
  },
  notification_test = {
    label = "Notification test",
    command = "",
    notify = true,
  },
  media_play_pause = {
    label = "Media play-pause",
    command = "noctalia msg media toggle",
  },
  volume_up = {
    label = "Volume up",
    command = "noctalia msg volume-up",
  },
  volume_down = {
    label = "Volume down",
    command = "noctalia msg volume-down",
  },
  screenshot_region = {
    label = "Screenshot region",
    command = "noctalia msg screenshot-region",
  },
  clipboard = {
    label = "Clipboard",
    command = "noctalia msg panel-open clipboard",
  },
  launcher = {
    label = "Launcher",
    command = "noctalia msg panel-open launcher",
  },
  lock = {
    label = "Lock screen",
    command = "noctalia msg session lock",
  },
}

local triggerCommands = {
  A = configString("button_a_command"),
  B = configString("button_b_command"),
  C = configString("button_c_command"),
  D = configString("button_d_command"),
  lower_left = configString("lower_left_command"),
  lower_right = configString("lower_right_command"),
  timeplace = configString("timeplace_command"),
  finder = configString("finder_command"),
  unknown = configString("unknown_command"),
}

local triggerPresets = {
  A = configSelect("button_a_preset", "none"),
  B = configSelect("button_b_preset", "none"),
  C = configSelect("button_c_preset", "none"),
  D = configSelect("button_d_preset", "none"),
  lower_left = configSelect("lower_left_preset", "none"),
  lower_right = configSelect("lower_right_preset", "none"),
  timeplace = configSelect("timeplace_preset", "none"),
  finder = configSelect("finder_preset", "none"),
  unknown = configSelect("unknown_preset", "none"),
}

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

local function supportedBySelectedModel(trigger)
  local model = models[selectedModelId] or models.generic_abcd
  return contains(model.triggers, trigger)
end

local function modelSummaries()
  local rows = {}
  for _, id in ipairs(modelOrder) do
    local model = models[id]
    if model ~= nil then
      table.insert(rows, {
        id = model.id,
        display_name = model.display_name,
        module = model.module,
        support = model.support,
        adapter = model.adapter,
        triggers = model.triggers,
        capabilities = model.capabilities,
      })
    end
  end
  return rows
end

local function presetSummaries()
  local rows = {}
  for id, preset in pairs(actionPresets) do
    table.insert(rows, {
      id = id,
      label = preset.label,
      has_command = trim(preset.command) ~= "",
    })
  end
  return rows
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
local discoveredWatches = {}
local helperStarted = false

local selectedModel = modelForId(selectedModelId)

local status = {
  connected = false,
  mode = helperCommand ~= "" and "helper" or "mock",
  helper_configured = helperCommand ~= "",
  scan_configured = scanCommand ~= "",
  helper_ready = false,
  helper_started = false,
  helper_name = "",
  helper_version = "",
  helper_model = "",
  helper_capabilities = "",
  watch_model = selectedModel.id,
  watch_model_name = selectedModel.display_name,
  watch_model_module = selectedModel.module,
  watch_model_support = selectedModel.support,
  watch_name = "",
  watch_address = "",
  available_triggers = selectedModel.triggers,
  available_capabilities = selectedModel.capabilities,
  supported_models = modelSummaries(),
  action_presets = presetSummaries(),
  discovered_watches = discoveredWatches,
  last_trigger = "",
  last_button = "",
  last_action = "idle",
  last_action_detail = "",
  last_source = "",
  last_error = "",
  press_count = 0,
  heartbeat = 0,
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
  status.available_capabilities = model.capabilities
end

local function publish()
  refreshModelStatus()
  status.helper_started = helperStarted
  status.discovered_watches = discoveredWatches
  status.updated_at = status.updated_at or noctalia.formatTime("%H:%M:%S")

  noctalia.state.set("status", {
    connected = status.connected,
    mode = status.mode,
    helper_configured = status.helper_configured,
    scan_configured = status.scan_configured,
    helper_ready = status.helper_ready,
    helper_started = status.helper_started,
    helper_name = status.helper_name,
    helper_version = status.helper_version,
    helper_model = status.helper_model,
    helper_capabilities = status.helper_capabilities,
    watch_model = status.watch_model,
    watch_model_name = status.watch_model_name,
    watch_model_module = status.watch_model_module,
    watch_model_support = status.watch_model_support,
    watch_name = status.watch_name,
    watch_address = status.watch_address,
    available_triggers = status.available_triggers,
    available_capabilities = status.available_capabilities,
    supported_models = status.supported_models,
    action_presets = status.action_presets,
    discovered_watches = status.discovered_watches,
    last_trigger = status.last_trigger,
    last_button = status.last_button,
    last_action = status.last_action,
    last_action_detail = status.last_action_detail,
    last_source = status.last_source,
    last_error = status.last_error,
    press_count = status.press_count,
    heartbeat = status.heartbeat,
    updated_at = status.updated_at,
  })
end

local function recordError(message, source)
  local text = trim(message)
  if text == "" then
    text = "unknown error"
  end

  status.last_error = text
  status.last_source = source or "unknown"
  status.last_action = "error"
  status.last_action_detail = text
  status.updated_at = noctalia.formatTime("%H:%M:%S")

  noctalia.log(`casio-deck: {text}`)
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

local function setWatch(model, name, address)
  local normalized = normalizeModelId(model)
  if trim(model) ~= "" and models[normalized] ~= nil then
    selectedModelId = normalized
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

local function setConnected(connected, source)
  status.connected = connected == true
  if source == "helper" then
    status.helper_ready = true
  end
  status.last_source = source or "unknown"
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  if status.connected then
    status.last_action = "connected"
    status.last_action_detail = status.watch_name
  else
    status.last_action = "disconnected"
    status.last_action_detail = ""
  end
  publish()
end

local function resolveAction(trigger)
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
      noctalia.notify("Casio Deck", `Preset test from {trigger}`)
      return
    end

    runCommand(preset.command, trigger, "action")
  end
end

local function press(trigger, source)
  trigger = normalizeTrigger(trigger)
  if trigger == "" then
    recordError("empty trigger", source)
    return
  end

  if not supportedBySelectedModel(trigger) then
    recordError(`unsupported trigger for {selectedModelId}: {trigger}`, source)
    return
  end

  local kind, value = resolveAction(trigger)
  local label = actionLabel(kind, value)

  status.connected = true
  status.last_trigger = trigger
  status.last_button = trigger
  status.last_action = label
  status.last_action_detail = value
  status.last_source = source or "unknown"
  status.press_count += 1
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
  status.last_trigger = ""
  status.last_button = ""
  status.last_action = "idle"
  status.last_action_detail = ""
  status.last_source = ""
  status.last_error = ""
  status.press_count = 0
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function setHelperReady(payload)
  local name, version, model = string.match(payload, "^(%S+)%s+(%S+)%s*(.*)$")

  status.helper_ready = true
  status.helper_name = trim(name)
  status.helper_version = trim(version)
  status.helper_model = trim(model)
  status.last_source = "helper"
  status.last_action = "ready"
  status.last_action_detail = trim(model)
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function recordScan(payload)
  local model, name, address, support = string.match(payload, "^(%S+)%s+(.+)%s+(%S+)%s+(%S+)$")
  if model == nil then
    model, name, address = string.match(payload, "^(%S+)%s+(.+)%s+(%S+)$")
    support = ""
  end

  model = trim(model)
  name = trim(name)
  address = trim(address)
  support = trim(support)

  if model == "" and name == "" and address == "" then
    recordError(`invalid scan line: {payload}`, "helper")
    return
  end

  table.insert(discoveredWatches, 1, {
    model = normalizeModelId(model),
    raw_model = model,
    name = name,
    address = address,
    support = support,
    seen_at = noctalia.formatTime("%H:%M:%S"),
  })

  while #discoveredWatches > 10 do
    table.remove(discoveredWatches)
  end

  status.last_source = "helper"
  status.last_action = "scan_result"
  status.last_action_detail = name ~= "" and name or address
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()
end

local function handleHelperLine(line)
  local text = trim(line)
  if text == "" then
    return
  end

  local action, payload = string.match(text, "^(%S+)%s*(.*)$")
  action = string.lower(trim(action))
  payload = trim(payload)

  if action == "ready" then
    setHelperReady(payload)
  elseif action == "model" then
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
  elseif action == "scan" then
    recordScan(payload)
  elseif action == "watch" then
    local model, name, address = string.match(payload, "^(%S+)%s+(.+)%s+(%S+)$")
    if model == nil then
      model = payload
      name = ""
      address = ""
    end
    setWatch(model, name, address)
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
  elseif action == "error" then
    recordError(payload ~= "" and payload or "helper reported an error", "helper")
  else
    recordError(`invalid helper line: {text}`, "helper")
  end
end

local function startHelper(source)
  if helperCommand == "" then
    recordError("helper_command is empty; plugin is in mock/local mode", source or "helper")
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
  status.mode = "helper"
  status.helper_configured = true
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

local function startScan(source)
  if scanCommand == "" then
    status.last_source = source or "scan"
    status.last_action = "scan_requested"
    status.last_action_detail = "scan_command is empty; run the helper manually or configure scan_command"
    status.updated_at = noctalia.formatTime("%H:%M:%S")
    publish()
    return
  end

  status.last_source = source or "scan"
  status.last_action = "scan_started"
  status.last_action_detail = scanCommand
  status.updated_at = noctalia.formatTime("%H:%M:%S")
  publish()

  local ok, err = pcall(function()
    noctalia.runStream(scanCommand, handleHelperLine)
  end)

  if not ok then
    recordError(`failed to start scan command: {tostring(err)}`, source or "scan")
  end
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
  elseif action == "select_model" then
    setModel(payload, source)
  elseif action == "start_helper" then
    startHelper(source)
  elseif action == "stop_helper" then
    recordError("stopping a running helper requires reloading the plugin in current Noctalia v5", source)
  elseif action == "scan" then
    startScan(source)
  elseif action == "error" then
    recordError(payload, source)
  elseif action == "reset" then
    reset()
  elseif action == "status" then
    noctalia.notify(
      "Casio Deck",
      `model={status.watch_model} connected={tostring(status.connected)} trigger={status.last_trigger} count={status.press_count} error={status.last_error}`
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

if helperCommand ~= "" then
  startHelper("init")
end

noctalia.setUpdateInterval(5000)

function update()
  status.heartbeat += 1
  publish()
end

publish()
