import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var casioDeckService: pluginApi?.mainInstance?.casioDeckService || null
  property int currentTab: 0

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 760 * Style.uiScaleRatio
  property real contentPreferredHeight: 520 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  readonly property var tabModel: [
    { "title": "Overview", "icon": "layout-dashboard" },
    { "title": "Watch", "icon": "bluetooth" },
    { "title": "Functions", "icon": "keyboard" },
    { "title": "Settings", "icon": "settings" }
  ]

  anchors.fill: parent

  function serviceValue(key, fallback) {
    if (!casioDeckService || casioDeckService[key] === undefined || casioDeckService[key] === null)
      return fallback;
    return casioDeckService[key];
  }

  function triggerCommandLabel(trigger) {
    if (!casioDeckService)
      return "not set";

    var command = casioDeckService.commandForTrigger(trigger);
    return command.length > 0 ? command : "not set";
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    RowLayout {
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      Rectangle {
        Layout.preferredWidth: 132 * Style.uiScaleRatio
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          anchors {
            fill: parent
            margins: Style.marginM
          }
          spacing: Style.marginS

          Repeater {
            model: root.tabModel

            delegate: Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 52 * Style.uiScaleRatio
              radius: Style.radiusS
              color: root.currentTab === index ? Color.mPrimary : "transparent"

              RowLayout {
                anchors.fill: parent
                anchors.margins: Style.marginS
                spacing: Style.marginS

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeL * Style.uiScaleRatio
                  color: root.currentTab === index ? Color.mOnPrimary : Color.mOnSurfaceVariant
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.title
                  color: root.currentTab === index ? Color.mOnPrimary : Color.mOnSurface
                  font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentTab = index
              }
            }
          }

          Item {
            Layout.fillHeight: true
          }

          Text {
            Layout.fillWidth: true
            text: serviceValue("helperState", "idle")
            color: Color.mOnSurfaceVariant
            font.pointSize: Style.fontSizeXS * Style.uiScaleRatio
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurface
        radius: Style.radiusM

        ColumnLayout {
          anchors {
            fill: parent
            margins: Style.marginL
          }
          spacing: Style.marginL

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "watch"
              pointSize: Style.fontSizeXXL * Style.uiScaleRatio
              color: serviceValue("connected", false) ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                Layout.fillWidth: true
                text: "Casio Deck"
                color: Color.mOnSurface
                font.pointSize: Style.fontSizeXL * Style.uiScaleRatio
                font.weight: Font.Bold
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: serviceValue("watchName", "No watch selected")
                color: Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                elide: Text.ElideRight
              }
            }

            StatusBadge {
              text: serviceValue("connected", false) ? "connected" : "offline"
              active: serviceValue("connected", false)
            }
          }

          StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentTab

            OverviewTab {}
            WatchTab {}
            FunctionsTab {}
            SettingsTab {}
          }
        }
      }
    }
  }

  component StatusBadge : Rectangle {
    property string text: ""
    property bool active: false

    Layout.preferredWidth: 116 * Style.uiScaleRatio
    Layout.preferredHeight: 32 * Style.uiScaleRatio
    radius: Style.radiusS
    color: active ? Color.mPrimary : Color.mSurfaceVariant

    Text {
      anchors.centerIn: parent
      text: parent.text
      color: parent.active ? Color.mOnPrimary : Color.mOnSurfaceVariant
      font.pointSize: Style.fontSizeS * Style.uiScaleRatio
      font.weight: Font.Medium
      elide: Text.ElideRight
    }
  }

  component ActionButton : Rectangle {
    id: actionRoot

    property string text: ""
    property string icon: ""
    property bool accent: false
    signal clicked()

    Layout.preferredHeight: 38 * Style.uiScaleRatio
    Layout.minimumWidth: 118 * Style.uiScaleRatio
    radius: Style.radiusS
    color: accent ? Color.mPrimary : Color.mSurfaceVariant

    RowLayout {
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        visible: actionRoot.icon.length > 0
        icon: actionRoot.icon
        pointSize: Style.fontSizeM * Style.uiScaleRatio
        color: actionRoot.accent ? Color.mOnPrimary : Color.mOnSurface
      }

      Text {
        text: actionRoot.text
        color: actionRoot.accent ? Color.mOnPrimary : Color.mOnSurface
        font.pointSize: Style.fontSizeS * Style.uiScaleRatio
        font.weight: Font.Medium
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
  }

  component InfoRow : RowLayout {
    property string label: ""
    property string value: ""

    Layout.fillWidth: true
    spacing: Style.marginM

    Text {
      Layout.preferredWidth: 138 * Style.uiScaleRatio
      text: parent.label
      color: Color.mOnSurfaceVariant
      font.pointSize: Style.fontSizeS * Style.uiScaleRatio
      elide: Text.ElideRight
    }

    Text {
      Layout.fillWidth: true
      text: parent.value.length > 0 ? parent.value : "-"
      color: Color.mOnSurface
      font.pointSize: Style.fontSizeS * Style.uiScaleRatio
      font.family: Settings.data.ui.fontFixed
      elide: Text.ElideRight
    }
  }

  component Section : Rectangle {
    id: sectionRoot

    default property alias content: body.data
    property string title: ""

    Layout.fillWidth: true
    Layout.preferredHeight: body.implicitHeight + titleText.implicitHeight + Style.marginL * 2 + Style.marginS
    radius: Style.radiusM
    color: Color.mSurfaceVariant

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginS

      Text {
        id: titleText
        Layout.fillWidth: true
        text: sectionRoot.title
        color: Color.mOnSurface
        font.pointSize: Style.fontSizeM * Style.uiScaleRatio
        font.weight: Font.Bold
        elide: Text.ElideRight
      }

      ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Style.marginS
      }
    }
  }

  component OverviewTab : Flickable {
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true

    ColumnLayout {
      id: content
      width: parent.width
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Section {
          Layout.fillWidth: true
          title: "Runtime"

          InfoRow { label: "Connection"; value: serviceValue("connected", false) ? "connected" : "offline" }
          InfoRow { label: "Helper"; value: serviceValue("helperState", "idle") }
          InfoRow { label: "Last action"; value: serviceValue("lastAction", "idle") }
          InfoRow { label: "Updated"; value: serviceValue("updatedAt", "") }
        }

        Section {
          Layout.fillWidth: true
          title: "Last trigger"

          InfoRow { label: "Trigger"; value: serviceValue("lastTrigger", "") }
          InfoRow { label: "Source"; value: serviceValue("lastSource", "") }
          InfoRow { label: "Count"; value: String(serviceValue("pressCount", 0)) }
          InfoRow { label: "Error"; value: serviceValue("lastError", "") }
        }
      }

      Section {
        title: "Local test controls"

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          ActionButton {
            text: "Connect"
            icon: "plug"
            accent: true
            onClicked: casioDeckService && casioDeckService.connectWatch("panel")
          }

          ActionButton {
            text: "Press A"
            icon: "keyboard"
            onClicked: casioDeckService && casioDeckService.press("A", "panel")
          }

          ActionButton {
            text: "Disconnect"
            icon: "unplug"
            onClicked: casioDeckService && casioDeckService.disconnectWatch("panel")
          }

          ActionButton {
            text: "Reset"
            icon: "rotate-ccw"
            onClicked: casioDeckService && casioDeckService.reset()
          }
        }
      }
    }
  }

  component WatchTab : Flickable {
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true

    ColumnLayout {
      id: content
      width: parent.width
      spacing: Style.marginM

      Section {
        title: "Connected watch"

        InfoRow { label: "Model"; value: serviceValue("watchModel", "") }
        InfoRow { label: "Name"; value: serviceValue("watchName", "") }
        InfoRow { label: "Address"; value: serviceValue("watchAddress", "") }
        InfoRow { label: "Ready"; value: serviceValue("helperReady", false) ? "yes" : "no" }
      }

      Section {
        title: "Helper"

        InfoRow {
          label: "Command"
          value: casioDeckService ? String(casioDeckService.settingValue("helperCommand", "")) : ""
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          ActionButton {
            text: "Start helper"
            icon: "play"
            accent: true
            onClicked: casioDeckService && casioDeckService.startHelper()
          }

          ActionButton {
            text: "Stop helper"
            icon: "square"
            onClicked: casioDeckService && casioDeckService.stopHelper()
          }

          ActionButton {
            text: "Mock ABL"
            icon: "watch"
            onClicked: {
              if (!casioDeckService)
                return;
              casioDeckService.setWatch("casio_abl100we_3565", "Casio ABL-100WE-1A", "mock");
              casioDeckService.connectWatch("panel");
              casioDeckService.press("lower_right", "panel");
            }
          }
        }
      }
    }
  }

  component FunctionsTab : Flickable {
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true

    ColumnLayout {
      id: content
      width: parent.width
      spacing: Style.marginM

      Section {
        title: "Generic A-D triggers"

        TriggerRow { title: "Button A"; trigger: "A" }
        TriggerRow { title: "Button B"; trigger: "B" }
        TriggerRow { title: "Button C"; trigger: "C" }
        TriggerRow { title: "Button D"; trigger: "D" }
      }

      Section {
        title: "ABL-100WE logical triggers"

        TriggerRow { title: "Lower left"; trigger: "lower_left" }
        TriggerRow { title: "Lower right"; trigger: "lower_right" }
        TriggerRow { title: "TIME&PLACE"; trigger: "timeplace" }
        TriggerRow { title: "Phone Finder"; trigger: "finder" }
      }
    }
  }

  component TriggerRow : RowLayout {
    id: triggerRowRoot

    property string title: ""
    property string trigger: ""

    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      Text {
        Layout.fillWidth: true
        text: triggerRowRoot.title
        color: Color.mOnSurface
        font.pointSize: Style.fontSizeS * Style.uiScaleRatio
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        Layout.fillWidth: true
        text: "Command: " + triggerCommandLabel(triggerRowRoot.trigger)
        color: Color.mOnSurfaceVariant
        font.pointSize: Style.fontSizeXS * Style.uiScaleRatio
        font.family: Settings.data.ui.fontFixed
        elide: Text.ElideRight
      }
    }

    ActionButton {
      text: "Test"
      icon: "play"
      onClicked: casioDeckService && casioDeckService.press(triggerRowRoot.trigger, "panel")
    }
  }

  component SettingsTab : Flickable {
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true

    ColumnLayout {
      id: content
      width: parent.width
      spacing: Style.marginM

      Section {
        title: "Persistent settings"

        Text {
          Layout.fillWidth: true
          text: "Use the plugin settings gear to edit the helper command and trigger commands. This panel focuses on runtime status and test actions."
          color: Color.mOnSurfaceVariant
          font.pointSize: Style.fontSizeS * Style.uiScaleRatio
          wrapMode: Text.WordWrap
        }
      }

      Section {
        title: "Tomorrow test flow"

        InfoRow { label: "1"; value: "Keep phone Bluetooth/CASIO app disconnected" }
        InfoRow { label: "2"; value: "Start btmon capture in a terminal" }
        InfoRow { label: "3"; value: "Start helper from Watch tab" }
        InfoRow { label: "4"; value: "Hold C on the watch to connect" }
        InfoRow { label: "5"; value: "Try TIME&PLACE and Phone Finder" }
      }
    }
  }
}
