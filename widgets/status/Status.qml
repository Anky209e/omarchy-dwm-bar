import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.status"
  property QtObject telemetry: null
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen?root.QsWindow.window.screen.name:""
  readonly property var prefs:telemetry?telemetry.settings:({showCpu:true,showRam:true,showGpu:true,showVolume:true,cpuWarn:90,ramWarn:90,gpuWarn:95})
  visible:!telemetry || (telemetry.modeFor(monitorName)==="full" && (prefs.showCpu || prefs.showRam || prefs.showGpu || prefs.showVolume))
  readonly property string fastStatus:telemetry?telemetry.hardwareStatus:"loading"
  readonly property string gpuStatus:telemetry?telemetry.gpuStatus:"loading"
  function valueText(key,value,status){
    var code=status==="error"?"ERR":status==="sleep"?"SLP":status==="missing" || status==="unknown"?"N/A":status==="stale"?"…":value<0?"—":""
    return code?strings.t("sensorState").arg(strings.t("label."+key)).arg(code):strings.t(key).arg(Commons.I18n.formatNumber(value))
  }
  function statusHint(status){return strings.t("state."+status)}
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
      visible:root.prefs.showCpu
      reservedText: strings.t("cpu").arg(Commons.I18n.formatNumber(100))
      text: root.valueText("cpu",root.cpu,root.fastStatus)
      foreground: root.fastStatus==="error" ? themePalette.red : root.fastStatus!=="ok" ? themePalette.muted : root.cpu >= root.prefs.cpuWarn ? themePalette.red : themePalette.green
      tooltipText: root.statusHint(root.fastStatus)
      onPressed: function(button) { root.monitor(button, "btop") }
    }
    Block { visible:root.prefs.showCpu && (root.prefs.showRam || root.prefs.showGpu || root.prefs.showVolume); text:"|";interactive:false;fixedWidth:Style.space(4);horizontalMargin:0;opacity:0.3 }
    Block {
      visible:root.prefs.showRam
      reservedText: strings.t("ram").arg(Commons.I18n.formatNumber(100))
      text: root.valueText("ram",root.ram,root.fastStatus)
      foreground: root.fastStatus==="error" ? themePalette.red : root.fastStatus!=="ok" ? themePalette.muted : root.ram >= root.prefs.ramWarn ? themePalette.red : themePalette.blue
      tooltipText: root.statusHint(root.fastStatus)
      onPressed: function(button) { root.monitor(button, "btop") }
    }
    Block { visible:root.prefs.showRam && (root.prefs.showGpu || root.prefs.showVolume); text:"|";interactive:false;fixedWidth:Style.space(4);horizontalMargin:0;opacity:0.3 }
    Block {
      visible:root.prefs.showGpu
      reservedText: strings.t("gpu").arg(Commons.I18n.formatNumber(100))
      text: root.valueText("gpu",root.gpu,root.gpuStatus)
      foreground: root.gpuStatus==="error" ? themePalette.red : root.gpuStatus!=="ok" || !root.gpuAvailable ? themePalette.muted : root.gpu >= root.prefs.gpuWarn ? themePalette.yellow : themePalette.magenta
      tooltipText: root.statusHint(root.gpuStatus)
      onPressed: function(button) { root.monitor(button, "nvtop") }
    }
    Block { visible:root.prefs.showGpu && root.prefs.showVolume; text:"|";interactive:false;fixedWidth:Style.space(4);horizontalMargin:0;opacity:0.3 }
    Block {
      visible:root.prefs.showVolume
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
