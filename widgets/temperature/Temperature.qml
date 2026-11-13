import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.temperature"
  property QtObject telemetry: null
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen?root.QsWindow.window.screen.name:""
  readonly property string sensorStatus:telemetry?telemetry.gpuStatus:"loading"
  visible:!telemetry || (telemetry.modeFor(monitorName)==="full" && telemetry.settings.showTemperature)
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
    text: root.sensorStatus==="sleep"?strings.t("stateValue").arg("SLP"):root.sensorStatus==="error"?strings.t("stateValue").arg("ERR"):root.sensorStatus==="missing" || root.sensorStatus==="unknown"?strings.t("stateValue").arg("N/A"):root.sensorStatus==="stale"?strings.t("stateValue").arg("…"):root.temperature<0?strings.t("unavailable"):strings.t("temperature").arg(Commons.I18n.formatNumber(root.temperature))
    foreground: root.sensorStatus==="error"?themePalette.red:root.sensorStatus!=="ok" || root.temperature<0?themePalette.muted : root.temperature >= (root.telemetry?root.telemetry.settings.tempHot:85) ? themePalette.red : root.temperature >= (root.telemetry?root.telemetry.settings.tempWarm:75) ? themePalette.yellow : themePalette.cyan
    tooltipText: strings.t("state."+root.sensorStatus)
    onPressed: function(button) {
      if (button === Qt.RightButton) { if (root.telemetry) root.telemetry.refreshHardware() }
      else Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", "nvtop"])
    }
  }
}
