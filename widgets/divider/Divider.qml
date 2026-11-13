import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id:root
  property QtObject telemetry:null
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen?root.QsWindow.window.screen.name:""
  readonly property string role:String(setting("role","clock"))
  visible:!telemetry || (telemetry.modeFor(monitorName)==="full" && (role==="clock" || role==="temperature" && telemetry.settings.showTemperature || role==="status" && (telemetry.settings.showCpu || telemetry.settings.showRam || telemetry.settings.showGpu || telemetry.settings.showVolume)))
  implicitWidth: Style.space(5)
  implicitHeight: barSize
  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: "|"
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    color: Commons.Color.bar.text
    opacity: 0.5
  }
}
