import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.temperature"
  property int temperature: -1
  implicitWidth: button.implicitWidth
  implicitHeight: barSize
  ThemePalette { id: themePalette }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  FontMetrics { id: metrics; font.family: Style.font.family; font.pixelSize: Style.font.body }
  function update(raw) {
    var value = String(raw).trim()
    root.temperature = /^\d{1,3}$/.test(value) && Number(value) <= 150 ? Number(value) : -1
  }
  Process {
    id: sensor
    command: ["timeout", "2", "nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits", "-i", "0"]
    stdout: StdioCollector { onStreamFinished: root.update(text) }
    onExited: function(code) { if (code !== 0) root.temperature = -1 }
  }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!sensor.running) sensor.running = true }
  WidgetButton {
    id: button
    bar: root.bar
    fixedWidth: Math.ceil(metrics.advanceWidth(strings.t("temperature").arg(Commons.I18n.formatNumber(100)))) + Style.space(2)
    fixedHeight: root.barSize
    horizontalMargin: 1
    pressScale: 1
    text: root.temperature < 0 ? strings.t("unavailable") : strings.t("temperature").arg(Commons.I18n.formatNumber(root.temperature))
    foreground: root.temperature < 0 ? themePalette.muted : root.temperature >= 85 ? themePalette.red : root.temperature >= 75 ? themePalette.yellow : themePalette.cyan
    tooltipText: strings.t("hint")
    onPressed: Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", "nvtop"])
  }
}
