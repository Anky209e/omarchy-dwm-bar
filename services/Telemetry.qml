import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import "TelemetryModel.js" as Model

// One instance belongs to DwmBar, never to a monitor or widget delegate.
Item {
  id: root
  property var shell: null
  property bool gamingEnabled: true
  property var extraGameClasses: []
  property var hardware: ({total: 0, idle: 0, cpu: -1, ram: -1})
  property var gpu: ({available: false, gpu: -1, temperature: -1})
  property bool gameDetected: false
  property bool gameReady: false
  property bool probePending: false
  property int games: 0
  property int fastRequests: 0
  property int gpuRequests: 0
  property bool recording: false
  readonly property bool hardwarePaused: gamingEnabled && gameDetected
  readonly property var idle: shell ? shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var night: shell ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var notifications: shell ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var state: ({awake: idle ? idle.stayAwake : false, night: night ? night.enabled : false,
                                recording: recording, dnd: notifications ? notifications.doNotDisturb : false})
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : -1
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  function helper(mode) { return ["python", Qt.resolvedUrl("telemetry.py").toString().replace("file://", ""), mode] }
  function refreshFast(manual) {
    if ((!manual && root.hardwarePaused) || fast.running) return
    fast.command = helper(manual ? "snapshot" : "hardware")
    fastRequests++
    fast.running = true
  }
  function refreshGpu(manual) {
    if ((!manual && root.hardwarePaused) || gpuRead.running) return
    gpuRequests++
    gpuRead.running = true
  }
  function refreshHardware() { refreshFast(true); refreshGpu(true) }
  function refreshRecording() { if (!recordingRead.running) recordingRead.running = true }
  function refreshGaming() {
    if (gameProbe.running) { probePending = true; return }
    gameProbe.command = helper("gaming").concat([JSON.stringify({classes: Array.isArray(extraGameClasses) ? extraGameClasses.slice(0,64) : []})])
    gameProbe.running = true
  }
  function toggleIdle() { if (idle) idle.setIdleEnabled(root.state.awake) }
  function toggleNight() { if (night) night.setNightlight(!root.state.night) }
  function toggleDnd() { if (notifications) notifications.setDoNotDisturb(!root.state.dnd) }
  function record() {
    if (recordAction.running) return
    recordAction.command = recording ? ["omarchy", "screenrecord", "--stop-recording"] : ["omarchy-menu", "toggle", "trigger.capture.screenrecord"]
    recordAction.running = true
  }
  onHardwarePausedChanged: hardware = Model.resetBaseline(hardware)
  onExtraGameClassesChanged: gameDebounce.restart()
  Component.onCompleted: gameDebounce.restart()

  Process {
    id: fast
    stdout: StdioCollector { onStreamFinished: { try { root.hardware = Model.hardware(root.hardware, JSON.parse(text)) } catch(e) {} } }
  }
  Process {
    id: gpuRead
    command: root.helper("gpu")
    stdout: StdioCollector { onStreamFinished: { try { root.gpu = Model.gpu(JSON.parse(text)) } catch(e) { root.gpu = Model.gpu(null) } } }
    onExited: function(code) { if (code !== 0) root.gpu = Model.gpu(null) }
  }
  Process {
    id: gameProbe
    stdout: StdioCollector {
      onStreamFinished: {
        try { var data = JSON.parse(text); root.gameDetected = data.gaming === true; root.games = Number(data.games) || 0 }
        catch(e) { root.gameDetected = false; root.games = 0 }
        root.gameReady = true
      }
    }
    onExited: Qt.callLater(function() {
      root.gameReady = true
      if (root.probePending) { root.probePending = false; root.refreshGaming() }
    })
  }
  Process { id: recordingRead; command: ["omarchy-capture-screenrecording", "--status"]; onExited: function(code) { root.recording = code === 0 } }
  Process { id: recordAction; onExited: Qt.callLater(root.refreshRecording) }
  Timer { interval: 2000; running: root.gameReady && !root.hardwarePaused; repeat: true; triggeredOnStart: true; onTriggered: root.refreshFast(false) }
  Timer { interval: 5000; running: root.gameReady && !root.hardwarePaused; repeat: true; triggeredOnStart: true; onTriggered: root.refreshGpu(false) }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshRecording() }
  Timer { id: gameDebounce; interval: 150; onTriggered: root.refreshGaming() }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (["fullscreen", "workspace", "workspacev2", "moveworkspace", "moveworkspacev2", "openwindow", "closewindow", "movewindow", "movewindowv2", "monitoradded", "monitoraddedv2", "monitorremoved", "activespecial", "activespecialv2"].indexOf(name) >= 0) gameDebounce.restart()
    }
  }
  ShellIpc {
    target: "dwm.bar"
    function telemetry(): string {
      return JSON.stringify({hardwarePaused: root.hardwarePaused, games: root.games, fastRequests: root.fastRequests,
                             gpuRequests: root.gpuRequests, cpu: root.hardware.cpu, ram: root.hardware.ram,
                             gpu: root.gpu.gpu, temperature: root.gpu.temperature, volume: root.volumePercent})
    }
    function refresh(): void { root.refreshHardware() }
  }
}
