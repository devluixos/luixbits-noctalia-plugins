-- Casio Deck desktop setup widget.
--
-- This is the temporary Noctalia v5 UI until plugins can provide bar dropdown
-- panels. The bridge service owns the state; this widget renders tabs and sends
-- normalized commands back to the bridge.

local activeTab = "overview"

local current = {
  connected = false,
  mode = "mock",
  helper_configured = false,
  scan_configured = false,
  helper_ready = false,
  helper_started = false,
  helper_name = "",
  helper_version = "",
  helper_model = "",
  helper_capabilities = "",
  watch_model = "generic_abcd",
  watch_model_name = "Generic A/B/C/D",
  watch_model_module = "",
  watch_model_support = "supported",
  watch_name = "",
  watch_address = "",
  available_triggers = { "A", "B", "C", "D" },
  available_capabilities = {},
  discovered_watches = {},
  last_trigger = "",
  last_button = "",
  last_action = "idle",
  last_action_detail = "",
  last_source = "",
  last_error = "",
  press_count = 0,
  heartbeat = 0,
  updated_at = "",
}

local modelRows = {
  {
    id = "generic_abcd",
    name = "Generic A/B/C/D",
    support = "supported",
    module = "",
    triggers = "A, B, C, D",
  },
  {
    id = "casio_abl100we_3565",
    name = "Casio ABL-100WE-1A",
    support = "experimental",
    module = "3565",
    triggers = "lower_left, lower_right, timeplace, finder, unknown",
  },
  {
    id = "future_casio_ble",
    name = "Other Casio Bluetooth watch",
    support = "unsupported",
    module = "",
    triggers = "adapter not implemented yet",
  },
}

local triggerMeta = {
  A = { label = "Button A", command = "button_a_command", preset = "button_a_preset", onClick = "pressA" },
  B = { label = "Button B", command = "button_b_command", preset = "button_b_preset", onClick = "pressB" },
  C = { label = "Button C", command = "button_c_command", preset = "button_c_preset", onClick = "pressC" },
  D = { label = "Button D", command = "button_d_command", preset = "button_d_preset", onClick = "pressD" },
  lower_left = {
    label = "Lower left",
    command = "lower_left_command",
    preset = "lower_left_preset",
    onClick = "pressLowerLeft",
  },
  lower_right = {
    label = "Lower right",
    command = "lower_right_command",
    preset = "lower_right_preset",
    onClick = "pressLowerRight",
  },
  timeplace = {
    label = "TIME&PLACE",
    command = "timeplace_command",
    preset = "timeplace_preset",
    onClick = "pressTimeplace",
  },
  finder = { label = "Finder", command = "finder_command", preset = "finder_preset", onClick = "pressFinder" },
  unknown = { label = "Unknown", command = "unknown_command", preset = "unknown_preset", onClick = "pressUnknown" },
}

local function trim(value)
  local text = tostring(value or "")
  local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
  return trimmed
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

local function boolText(flag)
  if flag then
    return "yes"
  end
  return "no"
end

local function tableHasItems(value)
  return type(value) == "table" and #value > 0
end

local function send(action, payload)
  noctalia.state.set("command", {
    action = action,
    payload = payload,
    trigger = payload,
    source = "desktop-dashboard",
    focusedOutputName = noctalia.focusedOutputName(),
  })
end

local function statLine(label, text, width)
  return ui.row({ gap = 8, align = "center" }, {
    ui.label({
      text = label,
      color = "on_surface_variant",
      fontSize = 12,
      maxWidth = width or 132,
      maxLines = 1,
    }),
    ui.label({
      text = value(text),
      color = "on_surface",
      fontSize = 12,
      fontWeight = "medium",
      maxWidth = 360,
      maxLines = 1,
    }),
  })
end

local function sectionTitle(text)
  return ui.label({
    text = text,
    color = "on_surface",
    fontSize = 15,
    fontWeight = "bold",
    maxLines = 1,
  })
end

local function muted(text, width)
  return ui.label({
    text = text,
    color = "on_surface_variant",
    fontSize = 12,
    maxWidth = width or 520,
    maxLines = 2,
  })
end

local function tabButton(tab, label, glyph, callback)
  return ui.button({
    text = label,
    glyph = glyph,
    variant = activeTab == tab and "primary" or "outline",
    onClick = callback,
  })
end

local function triggerList()
  if tableHasItems(current.available_triggers) then
    return current.available_triggers
  end

  if current.watch_model == "casio_abl100we_3565" then
    return { "lower_left", "lower_right", "timeplace", "finder", "unknown" }
  end

  if current.watch_model == "future_casio_ble" then
    return {}
  end

  return { "A", "B", "C", "D" }
end

local function mappingForTrigger(trigger)
  local meta = triggerMeta[trigger]
  if meta == nil then
    return "not configurable yet"
  end

  local mapText = configString("trigger_action_map")
  if mapText ~= "" then
    if string.find(mapText, trigger .. "=", 1, true) or string.find(mapText, trigger .. ":", 1, true) then
      return "advanced map"
    end
  end

  local preset = configString(meta.preset)
  if preset ~= "" and preset ~= "none" then
    return "preset:" .. preset
  end

  local command = configString(meta.command)
  if command ~= "" then
    return "custom command"
  end

  return "not mapped"
end

local function triggerRow(trigger)
  local meta = triggerMeta[trigger] or { label = trigger, onClick = "pressUnknown" }
  return ui.row({ gap = 10, align = "center" }, {
    ui.label({
      text = meta.label,
      color = "on_surface",
      fontSize = 13,
      fontWeight = "medium",
      maxWidth = 140,
      maxLines = 1,
    }),
    ui.label({
      text = mappingForTrigger(trigger),
      color = "on_surface_variant",
      fontSize = 12,
      maxWidth = 260,
      maxLines = 1,
    }),
    ui.spacer({ flexGrow = 1 }),
    ui.button({
      text = "Test",
      glyph = "player-play",
      variant = "secondary",
      onClick = meta.onClick,
    }),
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

local function detectedRows()
  local rows = {}
  local watches = current.discovered_watches

  if not tableHasItems(watches) then
    table.insert(rows, muted("No scan results yet. Run the helper with scan support, then press Scan.", 520))
    return rows
  end

  local maxRows = #watches
  if maxRows > 4 then
    maxRows = 4
  end

  for index = 1, maxRows do
    local watch = watches[index]
    if type(watch) == "table" then
      table.insert(rows, ui.row({ gap = 10, align = "center" }, {
        ui.glyph({ name = "bluetooth", size = 18, color = "primary" }),
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.label({
            text = value(watch.name, "Unknown Casio watch"),
            color = "on_surface",
            fontSize = 13,
            fontWeight = "medium",
            maxWidth = 380,
            maxLines = 1,
          }),
          ui.label({
            text = value(watch.model) .. " - " .. value(watch.address) .. " - " .. value(watch.support),
            color = "on_surface_variant",
            fontSize = 11,
            maxWidth = 430,
            maxLines = 1,
          }),
        }),
      }))
    end
  end

  return rows
end

local function modelCard(model)
  local selected = current.watch_model == model.id
  return ui.column({
    gap = 6,
    padding = 10,
    fill = selected and "primary_container" or "surface_variant",
    radius = 6,
    border = selected and "primary" or "outline_variant",
    borderWidth = 1,
  }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({
        name = selected and "circle-check" or "device-watch",
        size = 17,
        color = selected and "primary" or "on_surface_variant",
      }),
      ui.label({
        text = model.name,
        color = "on_surface",
        fontSize = 13,
        fontWeight = "bold",
        maxWidth = 320,
        maxLines = 1,
      }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({
        text = model.support,
        color = model.support == "unsupported" and "error" or "primary",
        fontSize = 11,
        maxLines = 1,
      }),
    }),
    muted("Module " .. value(model.module, "-") .. " - " .. model.triggers, 500),
    ui.button({
      text = selected and "Selected" or "Select",
      glyph = "cursor-click",
      variant = selected and "secondary" or "outline",
      onClick = model.id == "generic_abcd" and "selectGenericModel"
        or (model.id == "casio_abl100we_3565" and "selectAblModel" or "selectFutureModel"),
    }),
  })
end

local function overviewTab()
  local helperText = current.helper_configured
    and (current.helper_started and "running" or "configured")
    or "mock/local"

  return ui.column({ gap = 12 }, {
    sectionTitle("Overview"),
    ui.row({ gap = 12, align = "start" }, {
      ui.column({ gap = 5, flexGrow = 1 }, {
        statLine("Connection", current.connected and "Connected" or "Offline"),
        statLine("Selected watch", current.watch_model_name),
        statLine("Model id", current.watch_model),
        statLine("Support", current.watch_model_support),
        statLine("Helper", helperText),
        statLine("Scan command", current.scan_configured and "Configured" or "Not configured"),
        statLine("Helper ready", boolText(current.helper_ready)),
      }),
      ui.column({ gap = 5, flexGrow = 1 }, {
        statLine("Last trigger", current.last_trigger),
        statLine("Last action", current.last_action),
        statLine("Action detail", current.last_action_detail),
        statLine("Source", current.last_source),
        statLine("Press count", tostring(current.press_count)),
        statLine("Error", current.last_error),
      }),
    }),
    ui.separator({ color = "outline_variant", thickness = 1, spacing = 2 }),
    ui.row({ gap = 8, align = "center" }, {
      ui.button({ text = "Scan", glyph = "radar", variant = "secondary", onClick = "scanWatches" }),
      ui.button({ text = "Connect", glyph = "plug-connected", variant = "primary", onClick = "connectWatch" }),
      ui.button({ text = "Disconnect", glyph = "plug-off", variant = "outline", onClick = "disconnectWatch" }),
      ui.button({ text = "Reset", glyph = "rotate", variant = "outline", onClick = "resetDeck" }),
      ui.button({ text = "Test last", glyph = "player-play", variant = "ghost", onClick = "testLastTrigger" }),
    }),
    muted("Quick diagnostics: " .. value(current.last_error, "no error") .. " - updated " .. value(current.updated_at), 580),
  })
end

local function connectionTab()
  local modelCards = {}
  for _, model in ipairs(modelRows) do
    table.insert(modelCards, modelCard(model))
  end

  return ui.column({ gap = 12 }, {
    sectionTitle("Connection"),
    muted("Select the expected watch adapter, then run the helper. ABL-100WE is the first experimental adapter.", 580),
    ui.row({ gap = 8, align = "center" }, {
      ui.button({ text = "Start helper", glyph = "player-play", variant = "primary", onClick = "startHelper" }),
      ui.button({ text = "Stop helper", glyph = "player-stop", variant = "outline", onClick = "stopHelper" }),
      ui.button({ text = "Scan", glyph = "bluetooth-searching", variant = "secondary", onClick = "scanWatches" }),
      ui.button({ text = "Status", glyph = "info-circle", variant = "ghost", onClick = "statusDeck" }),
    }),
    muted(current.scan_configured and "Scan runs the configured scan_command and lists helper scan results below." or "Set scan_command in plugin settings to make this Scan button run a real BLE scan.", 580),
    ui.column({ gap = 8 }, modelCards),
    ui.separator({ color = "outline_variant", thickness = 1, spacing = 2 }),
    sectionTitle("Detected Watches"),
    ui.column({ gap = 8 }, detectedRows()),
  })
end

local function functionsTab()
  return ui.column({ gap = 12 }, {
    sectionTitle("Functions"),
    muted("Mappings are stored in plugin settings. The buttons below test the same trigger path used by the helper.", 580),
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "device-watch", size = 18, color = "primary" }),
      ui.label({
        text = value(current.watch_model_name),
        color = "on_surface",
        fontSize = 13,
        fontWeight = "bold",
        maxLines = 1,
        maxWidth = 320,
      }),
      ui.label({
        text = value(current.watch_model_support),
        color = current.watch_model_support == "unsupported" and "error" or "primary",
        fontSize = 12,
        maxLines = 1,
      }),
    }),
    ui.column({ gap = 8 }, triggerRows()),
    ui.separator({ color = "outline_variant", thickness = 1, spacing = 2 }),
    muted("Presets: notification_test, media_play_pause, volume_up, volume_down, screenshot_region, clipboard, launcher, lock.", 580),
    muted("Advanced map format: trigger=preset:media_play_pause or trigger=command:notify-send Casio Deck.", 580),
  })
end

local function aboutTab()
  local youtubeUrl = value(configString("youtube_channel_url"), "https://www.youtube.com/@LuixBits")
  local videoUrl = value(configString("explanation_video_url"), "video URL not set yet")

  return ui.column({ gap = 12 }, {
    sectionTitle("About"),
    muted("Casio Deck turns supported Casio Bluetooth watch events into Noctalia actions. Bluetooth decoding runs in the Python helper; Noctalia handles state, UI, and desktop commands.", 580),
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = "brand-youtube", size = 22, color = "error" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({
          text = "LuixBits",
          color = "on_surface",
          fontSize = 16,
          fontWeight = "bold",
          maxLines = 1,
        }),
        muted(youtubeUrl, 500),
      }),
    }),
    statLine("Support level", "ABL-100WE module 3565 experimental; other Casio BLE watches need adapters.", 110),
    statLine("Explanation video", videoUrl, 110),
    statLine("Helper", "Python, bleak, gshock-api adapter registry", 110),
  })
end

local function content()
  if activeTab == "connection" then
    return connectionTab()
  elseif activeTab == "functions" then
    return functionsTab()
  elseif activeTab == "about" then
    return aboutTab()
  end
  return overviewTab()
end

local function render()
  local connectedColor = current.connected and "primary" or "on_surface_variant"
  local stateText = current.connected and "Connected" or "Offline"
  local helperText = current.helper_configured
    and (current.helper_ready and "Helper ready" or "Helper configured")
    or "Mock/local mode"

  desktopWidget.render(ui.column({
    gap = 12,
    padding = 16,
    minWidth = 640,
    fill = "surface",
    radius = 8,
    border = "outline_variant",
    borderWidth = 1,
  }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = "device-watch", size = 24, color = connectedColor }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({
          text = "Casio Deck",
          fontSize = 20,
          fontWeight = "bold",
          color = "on_surface",
          maxLines = 1,
        }),
        ui.label({
          text = stateText .. " - " .. helperText .. " - " .. value(current.watch_model_name),
          fontSize = 12,
          color = "on_surface_variant",
          maxLines = 1,
          maxWidth = 500,
        }),
      }),
      ui.label({
        text = "#" .. tostring(current.press_count),
        fontSize = 18,
        fontWeight = "bold",
        color = "primary",
      }),
    }),

    ui.row({ gap = 8, align = "center" }, {
      tabButton("overview", "Overview", "dashboard", "showOverviewTab"),
      tabButton("connection", "Connection", "bluetooth", "showConnectionTab"),
      tabButton("functions", "Functions", "sparkles", "showFunctionsTab"),
      tabButton("about", "About", "info-circle", "showAboutTab"),
    }),

    ui.separator({ color = "outline_variant", thickness = 1, spacing = 2 }),
    content(),
  }))
end

local function applyStatus(status)
  if type(status) == "table" then
    current.connected = status.connected == true
    current.mode = status.mode or "mock"
    current.helper_configured = status.helper_configured == true
    current.scan_configured = status.scan_configured == true
    current.helper_ready = status.helper_ready == true
    current.helper_started = status.helper_started == true
    current.helper_name = status.helper_name or ""
    current.helper_version = status.helper_version or ""
    current.helper_model = status.helper_model or ""
    current.helper_capabilities = status.helper_capabilities or ""
    current.watch_model = status.watch_model or "generic_abcd"
    current.watch_model_name = status.watch_model_name or current.watch_model
    current.watch_model_module = status.watch_model_module or ""
    current.watch_model_support = status.watch_model_support or ""
    current.watch_name = status.watch_name or ""
    current.watch_address = status.watch_address or ""
    current.available_triggers = status.available_triggers or current.available_triggers
    current.available_capabilities = status.available_capabilities or {}
    current.discovered_watches = status.discovered_watches or {}
    current.last_trigger = status.last_trigger or ""
    current.last_button = status.last_button or ""
    current.last_action = status.last_action or "idle"
    current.last_action_detail = status.last_action_detail or ""
    current.last_source = status.last_source or ""
    current.last_error = status.last_error or ""
    current.press_count = status.press_count or 0
    current.heartbeat = status.heartbeat or 0
    current.updated_at = status.updated_at or ""
  end
  render()
end

function showOverviewTab()
  activeTab = "overview"
  render()
end

function showConnectionTab()
  activeTab = "connection"
  render()
end

function showFunctionsTab()
  activeTab = "functions"
  render()
end

function showAboutTab()
  activeTab = "about"
  render()
end

function selectGenericModel()
  send("select_model", "generic_abcd")
end

function selectAblModel()
  send("select_model", "casio_abl100we_3565")
end

function selectFutureModel()
  send("select_model", "future_casio_ble")
end

function startHelper()
  send("start_helper")
end

function stopHelper()
  send("stop_helper")
end

function scanWatches()
  send("scan")
end

function connectWatch()
  send("connect")
end

function disconnectWatch()
  send("disconnect")
end

function resetDeck()
  send("reset")
end

function statusDeck()
  send("status")
end

function testLastTrigger()
  if trim(current.last_trigger) ~= "" then
    send("press", current.last_trigger)
  else
    send("press", triggerList()[1])
  end
end

function pressA()
  send("press", "A")
end

function pressB()
  send("press", "B")
end

function pressC()
  send("press", "C")
end

function pressD()
  send("press", "D")
end

function pressLowerLeft()
  send("press", "lower_left")
end

function pressLowerRight()
  send("press", "lower_right")
end

function pressTimeplace()
  send("press", "timeplace")
end

function pressFinder()
  send("press", "finder")
end

function pressUnknown()
  send("press", "unknown")
end

function onIpc(event, payload)
  if event == "press" then
    send("press", payload)
  else
    send(event, payload)
  end
end

desktopWidget.setWantsSecondTicks(true)
applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)

function update()
  render()
end
