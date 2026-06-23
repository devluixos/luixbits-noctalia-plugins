import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editHelperCommand: valueFor("helperCommand")
  property string editWatchModel: valueFor("watchModel")
  property bool editNotifyOnPress: boolFor("notifyOnPress", true)
  property string editButtonACommand: valueFor("buttonACommand")
  property string editButtonBCommand: valueFor("buttonBCommand")
  property string editButtonCCommand: valueFor("buttonCCommand")
  property string editButtonDCommand: valueFor("buttonDCommand")
  property string editLowerLeftCommand: valueFor("lowerLeftCommand")
  property string editLowerRightCommand: valueFor("lowerRightCommand")
  property string editTimeplaceCommand: valueFor("timeplaceCommand")
  property string editFinderCommand: valueFor("finderCommand")

  spacing: Style.marginM

  function valueFor(key) {
    if (cfg && cfg[key] !== undefined && cfg[key] !== null)
      return String(cfg[key]);
    if (defaults && defaults[key] !== undefined && defaults[key] !== null)
      return String(defaults[key]);
    return "";
  }

  function boolFor(key, fallback) {
    if (cfg && cfg[key] !== undefined && cfg[key] !== null)
      return Boolean(cfg[key]);
    if (defaults && defaults[key] !== undefined && defaults[key] !== null)
      return Boolean(defaults[key]);
    return fallback;
  }

  function saveSettings() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.helperCommand = editHelperCommand;
    pluginApi.pluginSettings.watchModel = editWatchModel;
    pluginApi.pluginSettings.notifyOnPress = editNotifyOnPress;
    pluginApi.pluginSettings.buttonACommand = editButtonACommand;
    pluginApi.pluginSettings.buttonBCommand = editButtonBCommand;
    pluginApi.pluginSettings.buttonCCommand = editButtonCCommand;
    pluginApi.pluginSettings.buttonDCommand = editButtonDCommand;
    pluginApi.pluginSettings.lowerLeftCommand = editLowerLeftCommand;
    pluginApi.pluginSettings.lowerRightCommand = editLowerRightCommand;
    pluginApi.pluginSettings.timeplaceCommand = editTimeplaceCommand;
    pluginApi.pluginSettings.finderCommand = editFinderCommand;
    pluginApi.saveSettings();
    Logger.i("CasioDeck", "Settings saved");
  }

  NText {
    Layout.fillWidth: true
    text: "Casio Deck"
    pointSize: Style.fontSizeXXL
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NText {
    Layout.fillWidth: true
    text: "Temporary QML settings for the clickable panel UI. The v5 plugin settings remain separate."
    pointSize: Style.fontSizeM
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  Field {
    title: "Watch model"
    description: "Static model id used by the temporary panel."
    value: root.editWatchModel
    onValueChanged: root.editWatchModel = value
  }

  Field {
    title: "Helper command"
    description: "Command started from the Watch tab. Use the run-abl100-helper wrapper for real tests."
    value: root.editHelperCommand
    onValueChanged: root.editHelperCommand = value
  }

  NToggle {
    label: "Notify on press"
    checked: root.editNotifyOnPress
    onToggled: checked => root.editNotifyOnPress = checked
  }

  NText {
    Layout.fillWidth: true
    text: "Trigger commands"
    pointSize: Style.fontSizeL
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  Field { title: "Button A"; description: "Shell command for generic trigger A."; value: root.editButtonACommand; onValueChanged: root.editButtonACommand = value }
  Field { title: "Button B"; description: "Shell command for generic trigger B."; value: root.editButtonBCommand; onValueChanged: root.editButtonBCommand = value }
  Field { title: "Button C"; description: "Shell command for generic trigger C."; value: root.editButtonCCommand; onValueChanged: root.editButtonCCommand = value }
  Field { title: "Button D"; description: "Shell command for generic trigger D."; value: root.editButtonDCommand; onValueChanged: root.editButtonDCommand = value }
  Field { title: "Lower left"; description: "Shell command for ABL-100WE lower-left trigger."; value: root.editLowerLeftCommand; onValueChanged: root.editLowerLeftCommand = value }
  Field { title: "Lower right"; description: "Shell command for ABL-100WE lower-right trigger."; value: root.editLowerRightCommand; onValueChanged: root.editLowerRightCommand = value }
  Field { title: "TIME&PLACE"; description: "Shell command for TIME&PLACE trigger."; value: root.editTimeplaceCommand; onValueChanged: root.editTimeplaceCommand = value }
  Field { title: "Phone Finder"; description: "Shell command for Phone Finder trigger."; value: root.editFinderCommand; onValueChanged: root.editFinderCommand = value }

  component Field : ColumnLayout {
    id: fieldRoot

    property string title: ""
    property string description: ""
    property alias value: input.text

    signal valueChanged(string value)

    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: fieldRoot.title
      description: fieldRoot.description
    }

    NTextInput {
      id: input
      Layout.fillWidth: true
      Layout.preferredHeight: Style.baseWidgetSize
      onTextChanged: fieldRoot.valueChanged(text)
    }
  }
}
