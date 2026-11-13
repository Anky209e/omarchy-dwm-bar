import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.indicators"
  property QtObject telemetry: null
  readonly property var state: telemetry ? telemetry.state : ({awake: false, night: false, recording: false, dnd: false})
  implicitWidth: row.implicitWidth
  implicitHeight: barSize
  ThemePalette { id: themePalette }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  ShellIpc { target: "omarchy.indicators"; function refresh(): void { if (root.telemetry) root.telemetry.refreshRecording() } }
  component Icon: WidgetButton {
    bar: root.bar
    fixedWidth: Style.bar.statusSlot
    fixedHeight: root.barSize
    pressScale: 1
    foreground: themePalette.muted
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
