import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.settings"
  property QtObject telemetry: null
  property bool opened: false
  property int page: 0
  property var pluginEntries: []
  property bool confirmReset: false
  readonly property string monitorName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
  visible: !telemetry || telemetry.modeFor(monitorName) !== "hidden"
  readonly property int openPanelIndicatorWidth:Style.space(12)
  implicitWidth: button.implicitWidth
  implicitHeight: barSize
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  function open() { opened = true }
  function close() { opened = false; confirmReset = false }
  function toggle(key) { var patch = {}; patch[key] = !telemetry.settings[key]; telemetry.save(patch) }
  function number(key, value) { var patch = {}; patch[key] = value; telemetry.save(patch) }
  component Heading: PlainLabel {
    font.pixelSize: Style.font.caption
    font.bold: true
    color: Commons.Color.accent
  }
  WidgetButton {
    id: button
    bar: root.bar
    text: root.telemetry && root.telemetry.hardwarePaused ? "󰊗" : "󰒓"
    active: root.opened || (root.telemetry && root.telemetry.hardwarePaused)
    activeColor: Commons.Color.accent
    pressScale: 1
    tooltipText: strings.t("settings")
    onPressed: root.opened = !root.opened
  }
  KeyboardPanel {
    id: panel
    focusTarget: column
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(440)
    contentHeight: fittedContentHeight(column.implicitHeight)
    Column {
      id: column
      Keys.onEscapePressed: root.close()
      width: parent.width
      spacing: Style.space(12)
      Row {
        width: parent.width
        PlainLabel { width: parent.width - Style.space(36); anchors.verticalCenter: parent.verticalCenter; text: strings.t("settings"); font.pixelSize: Style.font.title; font.bold: true }
        StateButton { width: Style.space(32); height: Style.space(30); horizontalPadding: 0; verticalPadding: 0; iconText: "󰅖"; tooltipText: strings.t("close"); onClicked: root.close() }
      }
      Row {
        width: parent.width
        spacing: Style.space(6)
        Repeater {
          model: [strings.t("general"), strings.t("visible"), strings.t("displays")]
          StateButton {
            required property string modelData
            required property int index
            width: (parent.width - Style.space(12)) / 3
            text: modelData
            selected: root.page === index
            onClicked: root.page = index
          }
        }
      }
      PlainLabel { visible: root.telemetry && root.telemetry.settingsError; width: parent.width; wrapMode: Text.WordWrap; text: strings.t("saveError"); color: Commons.Color.urgent }
      Item {
        width: parent.width
        height: Math.min(Style.space(480), pages.implicitHeight)
        QQC.ScrollView {
          anchors.fill: parent
          contentWidth: availableWidth
          clip: true
          Column {
            id: pages
            width: parent.width
            Column {
              visible: root.page === 0
              width: parent.width
              spacing: Style.space(12)
              Grid {
                width: parent.width
                columns: 2
                spacing: Style.space(8)
                Repeater {
                  model: [{key:"overflowAlways",label:strings.t("overflowAlways")},{key:"gameMode",label:strings.t("gaming")},{key:"sleepAware",label:strings.t("sleep")}]
                  Toggle {
                    id: preferenceToggle
                    required property var modelData
                    property bool helpHovered: false
                    width: (parent.width - Style.space(8)) / 2
                    label: modelData.label
                    checked: root.telemetry ? root.telemetry.settings[modelData.key] : false
                    onClicked: root.toggle(modelData.key)
                    onHovered: function(value) { helpHovered = value }
                    PanelToolTip {
                      visible: root.opened && preferenceToggle.helpHovered
                      text: strings.t("help." + preferenceToggle.modelData.key)
                      width: Math.min(Style.space(300), implicitWidth)
                    }
                  }
                }
              }
              Heading { text: strings.t("polling") }
              Row {
                spacing: Style.space(8)
                NumberField { label: strings.t("cpuInterval"); from:1; to:30; value:root.telemetry?root.telemetry.settings.fastInterval:2; onModified:function(value){root.number("fastInterval",value)} }
                NumberField { label: strings.t("gpuInterval"); from:2; to:120; value:root.telemetry?root.telemetry.settings.gpuInterval:5; onModified:function(value){root.number("gpuInterval",value)} }
                NumberField { label: strings.t("musicWidth"); from:120; to:480; stepSize:20; value:root.telemetry?root.telemetry.settings.musicWidth:240; onModified:function(value){root.number("musicWidth",value)} }
              }
              Heading { text: strings.t("warnings") }
              Row {
                spacing: Style.space(8)
                NumberField { label: strings.t("cpuWarn"); from:1; to:100; value:root.telemetry?root.telemetry.settings.cpuWarn:90; onModified:function(value){root.number("cpuWarn",value)} }
                NumberField { label: strings.t("ramWarn"); from:1; to:100; value:root.telemetry?root.telemetry.settings.ramWarn:90; onModified:function(value){root.number("ramWarn",value)} }
                NumberField { label: strings.t("gpuWarn"); from:1; to:100; value:root.telemetry?root.telemetry.settings.gpuWarn:95; onModified:function(value){root.number("gpuWarn",value)} }
              }
              Row {
                spacing: Style.space(8)
                NumberField { label: strings.t("tempWarm"); from:30; to:110; value:root.telemetry?root.telemetry.settings.tempWarm:75; onModified:function(value){root.number("tempWarm",value)} }
                NumberField { label: strings.t("tempHot"); from:40; to:120; value:root.telemetry?root.telemetry.settings.tempHot:85; onModified:function(value){root.number("tempHot",value)} }
              }
              PlainLabel { text: root.telemetry && root.telemetry.savedAt > 0 ? strings.t("saved") : ""; font.pixelSize:Style.font.caption }
              StateButton { width:parent.width; text:root.confirmReset?strings.t("resetConfirm"):strings.t("reset"); tooltipText:strings.t("resetHelp"); onClicked:{if(root.confirmReset){root.telemetry.resetAppearance();root.confirmReset=false}else root.confirmReset=true} }
              StateButton { width: parent.width; iconText: "󰑐"; text: strings.t("refresh"); onClicked: root.telemetry.refreshHardware() }
            }
            Column {
              visible: root.page === 1
              width: parent.width
              spacing: Style.space(12)
              Heading { text: strings.t("visibleHelp") }
              Repeater {
                model: root.pluginEntries
                StateButton {
                  required property var modelData
                  width: parent.width
                  text: modelData.id
                  selected: root.telemetry && root.telemetry.pluginVisible(modelData.id)
                  onClicked: root.telemetry.togglePlugin(modelData.id)
                }
              }
              Grid {
                width: parent.width
                columns: 3
                spacing: Style.space(6)
                Repeater {
                  model: [{key:"showCpu",label:"CPU"},{key:"showRam",label:"RAM"},{key:"showGpu",label:"GPU"},{key:"showVolume",label:"VOL"},{key:"showTemperature",label:"TEMP"},{key:"showMusic",label:strings.t("music")},{key:"showIndicators",label:strings.t("indicators")},{key:"showConnections",label:strings.t("connections")},{key:"showPlugins",label:strings.t("plugins")},{key:"showTray",label:strings.t("tray")}]
                  StateButton {
                    required property var modelData
                    width: (parent.width - Style.space(12)) / 3
                    text: modelData.label
                    selected: root.telemetry ? root.telemetry.settings[modelData.key] : true
                    tooltipText: strings.t("help." + modelData.key)
                    onClicked: root.toggle(modelData.key)
                  }
                }
              }
            }
            Column {
              visible: root.page === 2
              width: parent.width
              spacing: Style.space(12)
              Repeater {
                model: Quickshell.screens
                Column {
                  required property var modelData
                  width: parent.width
                  spacing: Style.space(6)
                  Heading { text: modelData.name }
                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    Repeater {
                      model: [{value:"full",label:strings.t("full")},{value:"minimal",label:strings.t("minimal")},{value:"hidden",label:strings.t("hidden")}]
                      StateButton {
                        required property var modelData
                        property string output: parent.parent.modelData.name
                        width: (parent.width - Style.space(12)) / 3
                        text: modelData.label
                        selected: root.telemetry && root.telemetry.modeFor(output) === modelData.value
                        tooltipText: strings.t("help.mode." + modelData.value)
                        onClicked: root.telemetry.setMonitor(output,modelData.value)
                      }
                    }
                  }
                }
              }
              PlainLabel { width: parent.width; wrapMode: Text.WordWrap; text: strings.t("displayHelp"); color: Commons.Color.popups.text; opacity: 0.65; font.pixelSize: Style.font.caption }
            }
          }
        }
      }
    }
  }
}
