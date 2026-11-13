import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.status"
  property QtObject telemetry: null
  readonly property int cpu: telemetry ? telemetry.hardware.cpu : -1
  readonly property int ram: telemetry ? telemetry.hardware.ram : -1
  readonly property bool gpuAvailable: !!telemetry && telemetry.gpu.available
  readonly property int gpu: telemetry ? telemetry.gpu.gpu : -1
  readonly property bool muted: !!telemetry && telemetry.muted
  readonly property string volume: telemetry && telemetry.volumePercent >= 0 ? Commons.I18n.formatNumber(telemetry.volumePercent) + "%" : "—"
  readonly property bool hardwarePaused: !!telemetry && telemetry.hardwarePaused
  implicitHeight: barSize
  ThemePalette { id: themePalette }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  function monitor(button, program) {
    if (button === Qt.RightButton) { if (telemetry) telemetry.refreshHardware() }
    else Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", program])
  }
  implicitWidth: blocks.implicitWidth

  FontMetrics {
    id: blockMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }
  component Block: WidgetButton {
    property string reservedText: "|"
    fixedWidth: Math.ceil(blockMetrics.advanceWidth(reservedText)) + Style.space(2)
    bar: root.bar
    horizontalMargin: 1
    pressable: true
    pressScale: 1
    foreground: Commons.Color.bar.text
  }
  Row {
    id: blocks
    layoutDirection: Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    Block {
      reservedText: strings.t("cpu").arg(Commons.I18n.formatNumber(100))
      text: strings.t("cpu").arg(root.cpu < 0 ? "—" : Commons.I18n.formatNumber(root.cpu))
      foreground: root.hardwarePaused ? themePalette.muted : root.cpu >= 90 ? themePalette.red : themePalette.green
      tooltipText: root.hardwarePaused ? strings.t("paused") : strings.t("monitorHint")
      onPressed: function(button) { root.monitor(button, "btop") }
    }
    Block { text: "|"; interactive: false; fixedWidth: Style.space(4); horizontalMargin: 0; opacity: 0.3 }
    Block {
      reservedText: strings.t("ram").arg(Commons.I18n.formatNumber(100))
      text: strings.t("ram").arg(root.ram < 0 ? "—" : Commons.I18n.formatNumber(root.ram))
      foreground: root.hardwarePaused ? themePalette.muted : root.ram >= 90 ? themePalette.red : themePalette.blue
      tooltipText: root.hardwarePaused ? strings.t("paused") : strings.t("monitorHint")
      onPressed: function(button) { root.monitor(button, "btop") }
    }
    Block { text: "|"; interactive: false; fixedWidth: Style.space(4); horizontalMargin: 0; opacity: 0.3 }
    Block {
      reservedText: strings.t("gpu").arg(Commons.I18n.formatNumber(100))
      text: root.gpuAvailable ? strings.t("gpu").arg(Commons.I18n.formatNumber(root.gpu)) : strings.t("gpuUnavailable")
      foreground: root.hardwarePaused || !root.gpuAvailable ? themePalette.muted : root.gpu >= 95 ? themePalette.yellow : themePalette.magenta
      tooltipText: root.hardwarePaused ? strings.t("paused") : strings.t("monitorHint")
      onPressed: function(button) { root.monitor(button, "nvtop") }
    }
    Block { text: "|"; interactive: false; fixedWidth: Style.space(4); horizontalMargin: 0; opacity: 0.3 }
    Block {
      reservedText: strings.t("volume").arg("100%")
      text: strings.t("volume").arg(root.muted ? strings.t("muted") : root.volume)
      foreground: root.muted ? themePalette.muted : themePalette.cyan
      onPressed: function(button) {
        if (button === Qt.RightButton) Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        else Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.audio"])
      }
      onWheelMoved: function(delta) {
        if (delta !== 0) Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", delta > 0 ? "5%+" : "5%-"])
      }
    }
  }

}
