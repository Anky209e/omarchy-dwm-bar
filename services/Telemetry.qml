import QtQuick
import Quickshell
import qs.Commons as Commons
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import qs.Commons
import "TelemetryModel.js" as Model
import "WorkspaceModel.js" as WorkspaceModel

Item {
  id: root
  ThemePalette { id:sharedPalette }
  readonly property QtObject themePalette:sharedPalette
  property bool globalWorkspacePlan:false
  FileView {
    path:(Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/hypr/hyprmoncfg-monitors.lua"
    watchChanges:true;printErrors:false
    onLoaded:root.globalWorkspacePlan=WorkspaceModel.hasGlobalPlan(text())
    onFileChanged:reload()
    onLoadFailed:root.globalWorkspacePlan=false
  }
  property var shell: null
  property var settings: ({fastInterval:2,gpuInterval:5,cpuWarn:90,ramWarn:90,gpuWarn:95,tempWarm:75,tempHot:85,musicWidth:240,overflowAlways:false,gameMode:false,sleepAware:true,visualizer:true,remoteArtwork:false,showCpu:true,showRam:true,showGpu:true,showVolume:true,showTemperature:true,showIndicators:true,showTray:true,showConnections:true,showMusic:true,showPlugins:true,monitorDefault:"full",monitors:{},hiddenPlugins:[]})
  property var hardware: ({total:0,idle:0,cpu:-1,ram:-1})
  property var gpu: ({available:false,gpu:-1,temperature:-1})
  property string fastState: "loading"
  property string gpuState: "loading"
  property real fastAt: 0
  property real gpuAt: 0
  property real now: Date.now()
  property double savedAt: 0
  property var capabilities: ({})
  property string gpuVendor: ""
  property string gpuDevice: ""
  function monitorProgram(gpuMonitor) {
    if(gpuMonitor && capabilities.nvtop)return "nvtop"
    if(capabilities.btop)return "btop"
    if(capabilities.htop)return "htop"
    return capabilities.top?"top":""
  }
  function launchMonitor(gpuMonitor) {
    var program=monitorProgram(gpuMonitor)
    if(program)Quickshell.execDetached(["omarchy","launch","terminal","-e",program])
  }
  property bool settingsError: false
  property bool settingsReady: false
  property int fastRequests: 0
  property int gpuRequests: 0
  property bool recording: false
  property int restartCount: 0
  readonly property bool fullOutputVisible: {
    var screens=Quickshell.screens
    for(var i=0;i<screens.length;i++)if(modeFor(screens[i].name)==="full")return true
    return false
  }
  readonly property bool fastWanted: fullOutputVisible && (settings.showCpu || settings.showRam)
  readonly property bool gpuWanted: fullOutputVisible && (settings.showGpu || settings.showTemperature)
  onFastWantedChanged: syncWorker()
  onGpuWantedChanged: syncWorker()
  readonly property bool hardwarePaused: settings.gameMode === true
  readonly property string hardwareStatus: hardwarePaused ? "paused" : fastState === "ok" && now-fastAt > Math.max(10000,settings.fastInterval*3000) ? "stale" : fastState
  readonly property string gpuStatus: hardwarePaused ? "paused" : gpuState === "ok" && now-gpuAt > Math.max(15000,settings.gpuInterval*3000) ? "stale" : gpuState
  readonly property var idle: shell ? shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var night: shell ? shell.firstPartyServiceFor("omarchy.nightlight") : null
  readonly property var notifications: shell ? shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property var state: ({awake:idle ? idle.stayAwake:false,night:night ? night.enabled:false,recording:recording,dnd:notifications ? notifications.doNotDisturb:false})
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume*100) : -1
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  readonly property var players: Mpris.players.values
  property var selectedPlayer: null
  readonly property var player: {
    if (selectedPlayer && players.indexOf(selectedPlayer)>=0) return selectedPlayer
    for (var i=0;i<players.length;i++) if(players[i].isPlaying) return players[i]
    for (var j=0;j<players.length;j++) if(players[j].trackTitle) return players[j]
    return players.length ? players[0] : null
  }
  property var keyboards: ({})
  function reportKeyboard(name,state) {
    if(!name)return
    var previous=keyboards[name]
    if(state && previous && previous.label===state.label && previous.available===state.available)return
    var next={};for(var key in keyboards)if(key!==name)next[key]=keyboards[key]
    if(state)next[name]=state
    keyboards=next
  }
  property var musicUsers: ({})
  readonly property bool musicOpen: Object.keys(musicUsers).length>0
  readonly property bool visualizerWanted: musicOpen && !!player && player.isPlaying && settings.visualizer && !hardwarePaused
  property var spectrum: []
  property string spectrumState: "off"
  property string artSource: ""
  property string artState: "none"
  property string artRequest: ""
  readonly property string trackArt: player ? String(player.trackArtUrl || "").slice(0,4096) : ""

  function send(message) { if(worker.running) worker.write(JSON.stringify(message)+"\n") }
  function save(patch) { send({command:"settings",patch:patch}) }
  property int extraCount: 0
  function compactFor(name) {
    var screens=Quickshell.screens
    for(var i=0;i<screens.length;i++)if(screens[i].name===name)
      return settings.overflowAlways || screens[i].width < Commons.Style.space(1300 + extraCount*27 + Math.min(12,SystemTray.items.values.length)*27)
    return settings.overflowAlways===true
  }
  function pluginVisible(name) { return (settings.hiddenPlugins || []).indexOf(name)<0 }
  function togglePlugin(name) {
    var next=(settings.hiddenPlugins || []).slice(), at=next.indexOf(name)
    if(at<0)next.push(name);else next.splice(at,1)
    save({hiddenPlugins:next})
  }
  function resetAppearance() {
    save({fastInterval:2,gpuInterval:5,cpuWarn:90,ramWarn:90,gpuWarn:95,tempWarm:75,tempHot:85,musicWidth:240,showCpu:true,showRam:true,showGpu:true,showVolume:true,showTemperature:true,showIndicators:true,showTray:true,showConnections:true,showMusic:true,showPlugins:true,hiddenPlugins:[]})
  }
  function modeFor(name) { return settings.monitors[name] || settings.monitorDefault || "full" }
  function setMonitor(name,mode) {
    var next={};for(var key in settings.monitors)next[key]=settings.monitors[key]
    next[name]=mode;save({monitors:next})
  }
  function setMusicOpen(name,open) {
    var next={};for(var key in musicUsers)if(key!==name)next[key]=true
    if(open)next[name]=true
    musicUsers=next
  }
  function syncWorker() {
    send({command:"demand",fast:fastWanted,gpu:gpuWanted})
    send({command:"pause",paused:!settingsReady || hardwarePaused})
    send({command:"visualizer",enabled:visualizerWanted})
  }
  property bool artPolicy:false
  function requestArt() {
    if(artRequest===trackArt && artPolicy===settings.remoteArtwork && ["loading","ok","blocked","unsupported"].indexOf(artState)>=0)return
    artPolicy=settings.remoteArtwork
    artSource="";artState=trackArt ? "loading":"none";artRequest=trackArt
    if(musicOpen && trackArt)send({command:"art",url:trackArt,request:trackArt})
  }
  function refreshHardware() { send({command:"refresh"}) }
  function refreshRecording() { if(!recordingRead.running)recordingRead.running=true }
  function toggleIdle() { if(idle)idle.setIdleEnabled(state.awake) }
  function toggleNight() { if(night)night.setNightlight(!state.night) }
  function toggleDnd() { if(notifications)notifications.setDoNotDisturb(!state.dnd) }
  function record() {
    if(recordAction.running)return
    recordAction.command=recording ? ["omarchy","screenrecord","--stop-recording"]:["omarchy-menu","toggle","trigger.capture.screenrecord"]
    recordAction.running=true
  }
  function apply(line) {
    if(line.length>65536)return
    try {
      var data=JSON.parse(line)
      if(data.event==="capabilities") {
        var next={};for(var key in data.values)if(["btop","htop","top","nvtop","cava","nvidia-smi"].indexOf(key)>=0)next[key]=data.values[key]===true
        capabilities=next
      } else if(data.event==="settings") {
        settings=data.values;settingsReady=true;settingsError=false;savedAt=Date.now();syncWorker();if(musicOpen)requestArt()
      } else if(data.event==="settingsError")settingsError=true
      else if(data.event==="hardware") {
        fastState=data.status;fastRequests=Number(data.count)||0
        if(data.status==="ok"){hardware=Model.hardware(hardware,data.data);fastAt=Date.now()}
      } else if(data.event==="gpu") {
        gpuState=data.status;gpuRequests=Number(data.count)||0
        gpuVendor=data.data && typeof data.data.vendor==="string"?data.data.vendor.slice(0,32):""
        gpuDevice=data.data && typeof data.data.device==="string"?data.data.device.slice(0,32):""
        if(data.status==="ok"){gpu=Model.gpu(data.data);gpuAt=Date.now()}
      } else if(data.event==="art" && data.request===artRequest) {
        artSource=typeof data.source==="string" && data.source.indexOf("file://")===0 ? data.source:"";artState=data.status
      } else if(data.event==="spectrum" && Array.isArray(data.bars) && data.bars.length===16) {
        spectrum=data.bars.map(function(v){return Math.max(0,Math.min(1,Number(v)||0))});spectrumState=data.status
      }
    } catch(e){}
  }
  onHardwarePausedChanged: { hardware=Model.resetBaseline(hardware);syncWorker() }
  onVisualizerWantedChanged: send({command:"visualizer",enabled:visualizerWanted})
  onMusicOpenChanged: { if(musicOpen)requestArt();else {send({command:"artCancel"});artSource="";artState="none";artRequest=""} }
  onTrackArtChanged: { if(musicOpen)requestArt() }

  Process {
    id:worker
    command:["python","-u",Qt.resolvedUrl("worker.py").toString().replace("file://","")]
    stdinEnabled:true
    running:true
    stdout:SplitParser { onRead:function(line){root.apply(line)} }
    onStarted: { root.syncWorker() }
    onExited: { root.fastState="error";root.gpuState="error";root.restartCount++;restart.interval=Math.min(30000,1000*Math.pow(2,Math.min(5,root.restartCount)));restart.restart() }
  }
  Timer { id:restart;onTriggered:worker.running=true }
  Timer { interval:30000; running:worker.running; onTriggered:root.restartCount=0 }
  Timer { interval:1000;running:(root.fastWanted || root.gpuWanted) && !root.hardwarePaused;repeat:true;onTriggered:root.now=Date.now() }
  Process { id:recordingRead;command:["omarchy-capture-screenrecording","--status"];onExited:function(code){root.recording=code===0} }
  Process { id:recordAction;onExited:Qt.callLater(root.refreshRecording) }
  Timer { interval:5000;running:true;repeat:true;triggeredOnStart:true;onTriggered:root.refreshRecording() }
  ShellIpc {
    target:"dwm.bar"
    function telemetry():string {return JSON.stringify({fastWanted:root.fastWanted,gpuWanted:root.gpuWanted,hardwarePaused:root.hardwarePaused,gameMode:root.hardwarePaused,fastRequests:root.fastRequests,gpuRequests:root.gpuRequests,cpu:root.hardware.cpu,ram:root.hardware.ram,gpu:root.gpu.gpu,temperature:root.gpu.temperature,volume:root.volumePercent,hardwareStatus:root.hardwareStatus,gpuStatus:root.gpuStatus,visualizer:root.spectrumState,artwork:root.artState,musicOpen:root.musicOpen,capabilities:root.capabilities,gpuVendor:root.gpuVendor,gpuDevice:root.gpuDevice,backendRunning:worker.running})}
    function refresh():void{root.refreshHardware()}
    function preferences():string{return JSON.stringify(root.settings)}
    function reloadSettings():void{root.send({command:"reload"})}
  }
}
