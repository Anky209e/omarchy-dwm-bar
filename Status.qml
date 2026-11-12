import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "anky.dwm-status"
  property real previousTotal: 0
  property real previousIdle: 0
  property int cpu: -1
  property int ram: -1
  property string volume: "—"
  property bool muted: false
  ThemePalette { id: themePalette }
  Process {
    id: volumePoll
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    stdout: StdioCollector {
      onStreamFinished: {
        var match = text.match(/^Volume:\s+([0-9.]+)/)
        root.volume = match && isFinite(Number(match[1])) ? Commons.I18n.formatNumber(Math.round(Number(match[1]) * 100)) + "%" : "—"
        root.muted = text.indexOf("MUTED") >= 0
      }
    }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!volumePoll.running) volumePoll.running = true }
  Timer { id: volumeRefresh; interval: 150; onTriggered: if (!volumePoll.running) volumePoll.running = true }
  property bool gpuAvailable: false
  property int gpu: 0
  function updateGpu(raw) {
    var value = String(raw).trim()
    if (!/^\d{1,3}$/.test(value) || Number(value) > 100) { gpuAvailable = false; return }
    gpu = Number(value); gpuAvailable = true
  }

  Process {
    id: gpuPoll
    command: ["timeout", "2", "nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits", "-i", "0"]
    stdout: StdioCollector { onStreamFinished: root.updateGpu(text) }
    onExited: function(code) { if (code !== 0) root.gpuAvailable = false }
  }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!gpuPoll.running) gpuPoll.running = true }
  implicitHeight: barSize
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function update(raw) {
    var lines = raw.trim().split("\n")
    if (lines.length !== 2) return
    var fields = lines[0].trim().split(/\s+/).map(Number)
    if (fields.length < 8 || fields.some(function(n) { return !isFinite(n) || n < 0 })) return
    // Linux guest times are already included in user/nice: only sum eight fields.
    var total = fields.slice(0, 8).reduce(function(a, b) { return a + b }, 0)
    var idle = fields[3] + fields[4]
    if (previousTotal > 0 && total > previousTotal)
      cpu = Math.max(0, Math.min(100, Math.round(100 * (1 - (idle - previousIdle) / (total - previousTotal)))))
    previousTotal = total
    previousIdle = idle
    var memory = lines[1].trim().split(/\s+/).map(Number)
    if (memory.length === 2 && memory[0] > 0 && isFinite(memory[1]))
      ram = Math.max(0, Math.min(100, Math.round(100 * (1 - memory[1] / memory[0]))))
  }

  Process {
    id: stats
    command: ["sh", "-c", "awk '/^cpu / {for(i=2;i<=9;i++) printf \"%s%s\", $i, (i==9?\"\\n\":\" \")}' /proc/stat; awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {print t, a}' /proc/meminfo"]
    stdout: StdioCollector { onStreamFinished: root.update(text) }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!stats.running) stats.running = true }

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
      foreground: root.cpu >= 90 ? themePalette.red : themePalette.green
      onPressed: Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", "btop"])
    }
    Block { text: "|"; interactive: false; fixedWidth: Style.space(4); horizontalMargin: 0; opacity: 0.3 }
    Block {
      reservedText: strings.t("ram").arg(Commons.I18n.formatNumber(100))
      text: strings.t("ram").arg(root.ram < 0 ? "—" : Commons.I18n.formatNumber(root.ram))
      foreground: root.ram >= 90 ? themePalette.red : themePalette.blue
      onPressed: Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", "btop"])
    }
    Block { text: "|"; interactive: false; fixedWidth: Style.space(4); horizontalMargin: 0; opacity: 0.3 }
    Block {
      reservedText: strings.t("gpu").arg(Commons.I18n.formatNumber(100))
      text: root.gpuAvailable ? strings.t("gpu").arg(Commons.I18n.formatNumber(root.gpu)) : strings.t("gpuUnavailable")
      foreground: !root.gpuAvailable ? themePalette.muted : root.gpu >= 95 ? themePalette.yellow : themePalette.magenta
      onPressed: Quickshell.execDetached(["omarchy", "launch", "terminal", "-e", "nvtop"])
    }
    Block { text: "|"; interactive: false; fixedWidth: Style.space(4); horizontalMargin: 0; opacity: 0.3 }
    Block {
      reservedText: strings.t("volume").arg("100%")
      text: strings.t("volume").arg(root.muted ? strings.t("muted") : root.volume)
      foreground: root.muted ? themePalette.muted : themePalette.cyan
      onPressed: function(button) {
        if (button === Qt.RightButton) Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        else Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.audio"])
        volumeRefresh.restart()
      }
      onWheelMoved: function(delta) {
        if (delta !== 0) Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", delta > 0 ? "5%+" : "5%-"])
        volumeRefresh.restart()
      }
    }
  }

}
