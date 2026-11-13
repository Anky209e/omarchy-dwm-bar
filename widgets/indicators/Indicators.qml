import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.indicators"
  property var state: ({awake: false, night: false, recording: false, dnd: false})
  implicitWidth: row.implicitWidth
  implicitHeight: barSize
  ThemePalette { id: themePalette }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  function refresh() { if (!poll.running) poll.running = true }
  function action(command) {
    if (actionProcess.running) return
    actionProcess.command = command
    actionProcess.running = true
  }
  Process {
    id: poll
    command: ["python", Qt.resolvedUrl("state.py").toString().replace("file://", "")]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.state = {awake: data.awake === true, night: data.night === true, recording: data.recording === true, dnd: data.dnd === true}
        } catch(e) {}
      }
    }
  }
  Process { id: actionProcess; onExited: Qt.callLater(root.refresh) }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  ShellIpc { target: "omarchy.indicators"; function refresh(): void { root.broadcast("refresh") } }
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
    Icon { text: ""; active: root.state.awake; activeColor: themePalette.cyan; tooltipText: root.state.awake ? strings.t("idle") : strings.t("awake"); onPressed: root.action(["omarchy", "toggle", "idle"]) }
    Icon { text: "󰔎"; active: root.state.night; activeColor: themePalette.yellow; tooltipText: strings.t("night"); onPressed: root.action(["omarchy", "toggle", "nightlight"]) }
    Icon { text: "󰻂"; active: root.state.recording; activeColor: themePalette.red; tooltipText: root.state.recording ? strings.t("stop") : strings.t("record"); onPressed: root.action(root.state.recording ? ["omarchy", "screenrecord", "--stop-recording"] : ["omarchy-menu", "toggle", "trigger.capture.screenrecord"]) }
    Icon { text: "󰂛"; active: root.state.dnd; activeColor: themePalette.magenta; tooltipText: strings.t("dnd"); onPressed: root.action(["omarchy", "toggle", "notification", "silencing"]) }
  }
}
