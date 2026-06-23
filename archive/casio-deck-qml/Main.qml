import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property alias casioDeckService: service

  Item {
    id: service

    property string version: "0.1.0-qml"
    property bool connected: false
    property bool helperReady: false
    property bool helperRunning: false
    property string helperState: "idle"
    property string helperName: "local-qml"
    property string watchModel: settingValue("watchModel", "casio_abl100we_3565")
    property string watchName: "Casio ABL-100WE-1A"
    property string watchAddress: ""
    property string lastTrigger: ""
    property string lastAction: "idle"
    property string lastSource: "panel"
    property string lastError: ""
    property int pressCount: 0
    property string updatedAt: ""

    function settings() {
      return root.pluginApi && root.pluginApi.pluginSettings ? root.pluginApi.pluginSettings : ({});
    }

    function defaults() {
      return root.pluginApi && root.pluginApi.manifest && root.pluginApi.manifest.metadata
          && root.pluginApi.manifest.metadata.defaultSettings
        ? root.pluginApi.manifest.metadata.defaultSettings
        : ({});
    }

    function settingValue(key, fallback) {
      var cfg = settings();
      if (cfg && cfg[key] !== undefined && cfg[key] !== null) {
        return cfg[key];
      }

      var def = defaults();
      if (def && def[key] !== undefined && def[key] !== null) {
        return def[key];
      }

      return fallback;
    }

    function commandKeyForTrigger(trigger) {
      if (trigger === "A")
        return "buttonACommand";
      if (trigger === "B")
        return "buttonBCommand";
      if (trigger === "C")
        return "buttonCCommand";
      if (trigger === "D")
        return "buttonDCommand";
      if (trigger === "lower_left")
        return "lowerLeftCommand";
      if (trigger === "lower_right")
        return "lowerRightCommand";
      if (trigger === "timeplace")
        return "timeplaceCommand";
      if (trigger === "finder")
        return "finderCommand";
      return "";
    }

    function commandForTrigger(trigger) {
      var key = commandKeyForTrigger(trigger);
      if (key.length === 0)
        return "";

      var command = settingValue(key, "");
      return command ? String(command).trim() : "";
    }

    function now() {
      return new Date().toLocaleTimeString();
    }

    function notify(message) {
      if (settingValue("notifyOnPress", true) && ToastService) {
        ToastService.showNotice(message);
      }
    }

    function setWatch(model, name, address) {
      watchModel = model || watchModel;
      watchName = name || watchName;
      watchAddress = address || watchAddress;
      updatedAt = now();
    }

    function connectWatch(source) {
      connected = true;
      lastAction = "connect";
      lastSource = source || "panel";
      lastError = "";
      updatedAt = now();
    }

    function disconnectWatch(source) {
      connected = false;
      lastAction = "disconnect";
      lastSource = source || "panel";
      updatedAt = now();
    }

    function reset() {
      connected = false;
      helperReady = false;
      helperState = helperRunning ? "running" : "idle";
      lastTrigger = "";
      lastAction = "reset";
      lastSource = "panel";
      lastError = "";
      pressCount = 0;
      updatedAt = now();
    }

    function recordError(message, source) {
      var trimmed = (message || "").trim();
      if (trimmed.length === 0)
        return;

      lastError = trimmed;
      lastAction = "error";
      lastSource = source || "helper";
      updatedAt = now();
      Logger.w("CasioDeck", trimmed);
    }

    function press(trigger, source) {
      var normalized = trigger && trigger.length > 0 ? trigger : "unknown";
      lastTrigger = normalized;
      lastAction = "press";
      lastSource = source || "panel";
      pressCount += 1;
      connected = true;
      lastError = "";
      updatedAt = now();

      var command = commandForTrigger(normalized);
      if (command.length > 0) {
        Quickshell.execDetached(["sh", "-c", command]);
      }

      notify("Casio Deck: " + normalized + " #" + pressCount);
    }

    function handleHelperLine(line) {
      var trimmed = (line || "").trim();
      if (trimmed.length === 0)
        return;

      var parts = trimmed.split(/\s+/);
      var kind = parts[0];

      if (kind === "ready") {
        helperReady = true;
        helperName = parts.length > 1 ? parts[1] : "helper";
        if (parts.length > 3)
          watchModel = parts[3];
        helperState = "ready";
        lastAction = "ready";
        lastSource = "helper";
        lastError = "";
        updatedAt = now();
        return;
      }

      if (kind === "watch") {
        var model = parts.length > 1 ? parts[1] : watchModel;
        var address = parts.length > 2 ? parts[parts.length - 1] : "";
        var name = parts.length > 3 ? parts.slice(2, parts.length - 1).join(" ") : watchName;
        setWatch(model, name, address);
        lastAction = "watch";
        lastSource = "helper";
        return;
      }

      if (kind === "connect") {
        connectWatch("helper");
        return;
      }

      if (kind === "disconnect") {
        disconnectWatch("helper");
        return;
      }

      if (kind === "press") {
        press(parts.length > 1 ? parts[1] : "unknown", "helper");
        return;
      }

      if (kind === "error") {
        recordError(parts.slice(1).join(" "), "helper");
        return;
      }

      recordError("Ignored helper line: " + trimmed, "helper");
    }

    function startHelper() {
      var command = String(settingValue("helperCommand", "") || "").trim();
      if (command.length === 0) {
        recordError("No helperCommand configured", "panel");
        return;
      }

      if (helperProcess.running)
        helperProcess.running = false;

      helperProcess.command = ["sh", "-c", command];
      helperRunning = true;
      helperState = "running";
      lastAction = "start-helper";
      lastSource = "panel";
      lastError = "";
      updatedAt = now();
      helperProcess.running = true;
    }

    function stopHelper() {
      if (helperProcess.running)
        helperProcess.running = false;

      helperRunning = false;
      helperState = helperReady ? "ready" : "idle";
      lastAction = "stop-helper";
      lastSource = "panel";
      updatedAt = now();
    }
  }

  Process {
    id: helperProcess
    running: false
    command: ["sh", "-c", ""]

    stdout: SplitParser {
      onRead: data => service.handleHelperLine(data)
    }

    stderr: SplitParser {
      onRead: data => service.recordError(data, "helper-stderr")
    }

    onExited: (exitCode, exitStatus) => {
      service.helperRunning = false;
      if (exitCode === 0) {
        service.helperState = service.helperReady ? "ready" : "idle";
      } else {
        service.helperState = "failed";
        service.recordError("Helper exited with code " + exitCode, "helper");
      }
    }
  }

  Component.onCompleted: {
    service.updatedAt = service.now();
  }
}
