import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var casioDeckService: pluginApi?.mainInstance?.casioDeckService || null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool connected: casioDeckService?.connected ?? false
  readonly property bool helperRunning: casioDeckService?.helperRunning ?? false
  readonly property string lastTrigger: casioDeckService?.lastTrigger ?? ""
  readonly property int pressCount: casioDeckService?.pressCount ?? 0
  readonly property string displayText: {
    if (lastTrigger.length > 0)
      return "Casio " + lastTrigger + " #" + pressCount;
    return connected ? "Casio on" : "Casio";
  }

  readonly property string iconKey: {
    if (helperRunning)
      return "bluetooth-connected";
    if (connected)
      return "watch-check";
    return "watch";
  }

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.iconKey
    text: root.displayText
    forceOpen: true
    autoHide: false
    customTextIconColor: root.connected ? Color.mPrimary : Color.mOnSurfaceVariant

    tooltipText: {
      var lines = [];
      lines.push("Left click: Open Casio Deck");
      lines.push("Connected: " + (root.connected ? "yes" : "no"));
      lines.push("Helper: " + (root.helperRunning ? "running" : "stopped"));
      if (root.lastTrigger.length > 0)
        lines.push("Last trigger: " + root.lastTrigger + " #" + root.pressCount);
      return lines.join("\n");
    }

    onClicked: {
      if (pluginApi)
        pluginApi.openPanel(root.screen, root);
    }
  }
}
