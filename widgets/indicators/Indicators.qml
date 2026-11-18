import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.indicators"
  property QtObject telemetry: null
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen?root.QsWindow.window.screen.name:""
  visible:!telemetry || (telemetry.modeFor(monitorName)==="full" && telemetry.settings.showIndicators && !telemetry.compactFor(monitorName))
  readonly property var state: telemetry ? telemetry.state : ({awake: false, night: false, recording: false, dnd: false})
  implicitWidth: row.implicitWidth
  implicitHeight: barSize
  readonly property var themePalette: telemetry ? telemetry.themePalette : ({green:Commons.Color.accent,blue:Commons.Color.accent,magenta:Commons.Color.accent,cyan:Commons.Color.accent,yellow:Commons.Color.accent,red:Commons.Color.urgent,muted:Commons.Color.bar.text})
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  ShellIpc { target: "omarchy.indicators"; function refresh(): void { if (root.telemetry) root.telemetry.refreshRecording() } }
  component Icon: WidgetButton {
    bar: root.bar
    fixedWidth: Style.bar.statusSlot
    fixedHeight: root.barSize
    pressScale: 1
    foreground: Commons.Color.bar.text
    opacity: active ? 1 : 0.6
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(2)
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(12); height: Style.space(2)
      visible: parent.active
      color: parent.activeColor
    }
  }
  Row {
    id: row
    layoutDirection: Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    Icon { text: ""; active: root.state.awake; activeColor: themePalette.cyan; tooltipText: root.state.awake ? strings.t("idle") : strings.t("awake"); onPressed: root.telemetry.toggleIdle() }
    Icon { text: "󰔎"; active: root.state.night; activeColor: themePalette.yellow; tooltipText: strings.t("night"); onPressed: root.telemetry.toggleNight() }
    Icon { text: "󰻂"; active: root.state.recording; activeColor: themePalette.red; tooltipText: root.state.recording ? strings.t("stop") : strings.t("record"); onPressed: root.telemetry.record() }
    Icon { text: "󰂛"; active: root.state.dnd; activeColor: themePalette.magenta; tooltipText: strings.t("dnd"); onPressed: root.telemetry.toggleDnd() }
  }
}
