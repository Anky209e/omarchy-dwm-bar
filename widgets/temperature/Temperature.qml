import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.temperature"
  property QtObject telemetry: null
  readonly property int temperature: telemetry ? telemetry.gpu.temperature : -1
  readonly property bool hardwarePaused: !!telemetry && telemetry.hardwarePaused
  implicitWidth: button.implicitWidth
  implicitHeight: barSize
  ThemePalette { id: themePalette }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  FontMetrics { id: metrics; font.family: Style.font.family; font.pixelSize: Style.font.body }
  WidgetButton {
    id: button
    bar: root.bar
    fixedWidth: Math.ceil(metrics.advanceWidth(strings.t("temperature").arg(Commons.I18n.formatNumber(100)))) + Style.space(2)
    fixedHeight: root.barSize
    horizontalMargin: 1
    pressScale: 1
    text: root.temperature < 0 ? strings.t("unavailable") : strings.t("temperature").arg(Commons.I18n.formatNumber(root.temperature))
    foreground: root.hardwarePaused || root.temperature < 0 ? themePalette.muted : root.temperature >= 85 ? themePalette.red : root.temperature >= 75 ? themePalette.yellow : themePalette.cyan
    tooltipText: root.hardwarePaused ? strings.t("paused") : strings.t("hint")
    onPressed: function(button) {
      if (button === Qt.RightButton) { if (root.telemetry) root.telemetry.refreshHardware() }
      else Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", "nvtop"])
    }
  }
}
