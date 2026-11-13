import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import "services" as Services
import "services/LayoutModel.js" as LayoutModel
import "ui" as Ui
import "file:/usr/share/omarchy/shell/plugins/bar" as OmarchyBar
import "file:/usr/share/omarchy/shell/plugins/bar/BarModel.js" as NativeBarModel
import "widgets/workspaces" as Tags
import "widgets/music" as Music
import "widgets/status" as Status
import "widgets/temperature" as Temperature
import "widgets/indicators" as Indicators
import "widgets/divider" as Divider
import "widgets/tray" as Tray

// Reuse the installed shell's bar host and native panels. Only this root
// manifest is installed; all other components below are private QML widgets.
OmarchyBar.Bar {
  id: root
  property var inheritedRegistry: null
  Services.Telemetry {
    id: sharedTelemetry
    shell: root.shell
  }

  Component { id: tags; Tags.Workspaces { telemetry: sharedTelemetry } }
  Component { id: music; Music.Music { telemetry: sharedTelemetry } }
  Component { id: status; Status.Status { telemetry: sharedTelemetry } }
  Component { id: temperature; Temperature.Temperature { telemetry: sharedTelemetry } }
  Component { id: indicators; Indicators.Indicators { telemetry: sharedTelemetry } }
  Component { id: divider; Divider.Divider { telemetry: sharedTelemetry } }
  Component { id: tray; Tray.Tray { telemetry: sharedTelemetry } }

  Component { id: settings; Ui.Settings { telemetry: sharedTelemetry } }
  Component { id: clock; Ui.NativeSlot { telemetry: sharedTelemetry; role:"clock"; sourceComponent: root.nativeComponent("omarchy.clock") } }
  Component { id: network; Ui.NativeSlot { telemetry: sharedTelemetry; sourceComponent: root.nativeComponent("omarchy.network") } }
  Component { id: bluetooth; Ui.NativeSlot { telemetry: sharedTelemetry; sourceComponent: root.nativeComponent("omarchy.bluetooth") } }
  Component { id: audio; Ui.NativeSlot { telemetry: sharedTelemetry; sourceComponent: root.nativeComponent("omarchy.audio") } }
  Component { id: power; Ui.NativeSlot { telemetry: sharedTelemetry; sourceComponent: root.nativeComponent("omarchy.power") } }
  Component { id: keyboard; Ui.NativeSlot { telemetry: sharedTelemetry; sourceComponent: root.nativeComponent("omarchy.keyboard-layout") } }
  Component { id: pluginWidget; Ui.NativeSlot { telemetry: sharedTelemetry; role:"plugins"; sourceComponent: root.nativeComponent(moduleName) } }
  readonly property var configuredExtras: LayoutModel.configuredExtras(barConfig.layout, inheritedRegistry ? inheritedRegistry.widgets : {})
  onConfiguredExtrasChanged: applyBarConfig()
  readonly property var nativeComponents: ({"omarchy.clock":clock,"omarchy.network":network,"omarchy.bluetooth":bluetooth,"omarchy.audio":audio,"omarchy.power":power,"omarchy.keyboard-layout":keyboard})
  function nativeComponent(name) { return inheritedRegistry && inheritedRegistry.widgets[name] ? inheritedRegistry.widgets[name].component : null }
  function thicknessFor(screen) {
    if(screen && sharedTelemetry.modeFor(screen.name)==="hidden")return 0
    if(root.vertical || !screen)return root.barSize
    return Math.max(root.barSize, NativeBarModel.notchFloor(root.displayCutouts,root.position,screen.name,screen.width,screen.height,screen.devicePixelRatio,root.panelModeFor(screen),Style.bar.notchHeight))
  }
  ShellIpc {
    target:"dwm.bar.ui"
    function settings():void {
      var items=root.moduleWidgets("dwm.settings")
      var focused=Hyprland.focusedMonitor
      for(var i=0;i<items.length;i++)if(!focused || items[i].monitorName===focused.name){items[i].open();return}
      if(items.length)items[0].open()
    }
    function close():void {
      var ids=["dwm.music","dwm.settings"]
      for(var n=0;n<ids.length;n++){var items=root.moduleWidgets(ids[n]);for(var i=0;i<items.length;i++)items[i].close()}
    }
    function music():void {
      var items=root.moduleWidgets("dwm.music")
      var focused=Hyprland.focusedMonitor
      for(var i=0;i<items.length;i++)if(!focused || items[i].monitorName===focused.name){items[i].open();return}
      if(items.length)items[0].open()
    }
  }

  readonly property var internalComponents: ({
    "dwm.workspaces": tags,
    "dwm.music": music,
    "dwm.status": status,
    "dwm.temperature": temperature,
    "dwm.indicators": indicators,
    "dwm.divider": divider,
    "dwm.tray": tray,
    "dwm.settings":settings
  })

  QtObject {
    id: bundledRegistry
    readonly property int revision: root.inheritedRegistry ? root.inheritedRegistry.revision : 0
    readonly property var widgets: {
      var result = {}
      var nativeWidgets = root.inheritedRegistry ? root.inheritedRegistry.widgets : {}
      for (var name in nativeWidgets) result[name] = nativeWidgets[name]
      for (var nativeName in root.nativeComponents) {
        if(nativeWidgets[nativeName])result[nativeName]={component:root.nativeComponents[nativeName],metadata:nativeWidgets[nativeName].metadata}
      }
      for (var i = 0; i < root.configuredExtras.length; i++) {
        var pluginId = root.configuredExtras[i].id
        if(nativeWidgets[pluginId])result[pluginId] = {component:pluginWidget,metadata:nativeWidgets[pluginId].metadata}
      }
      for (var localName in root.internalComponents)
        result[localName] = {component: root.internalComponents[localName], metadata: {firstParty: false}}
      return result
    }
    function metadataFor(name) { return widgets[name] ? widgets[name].metadata : null }
  }

  function bindRegistry() {
    if (barWidgetRegistry === bundledRegistry) return
    inheritedRegistry = barWidgetRegistry
    barWidgetRegistry = bundledRegistry
  }
  onBarWidgetRegistryChanged: bindRegistry()

  // The shell injects the previous bar configuration when enabling this
  // plugin. Respect its background preference, but supply our own complete
  // layout without modifying shell.json or installing companion plugins.
  function applyBarConfig() {
    position = "top"
    var config = barConfig || {}
    var look = config.background || "opaque"
    setRequestedTransparency(look === "none")
    if (look !== "none") glassy = look === "glassy"
    if (look !== glassSyncedLook) {
      glassSyncedLook = look
      Util.execDetached("omarchy-bar sync-glass")
    }
    layoutConfig = normalizeLayout({
      left: [{id: "dwm.workspaces"}, {id: "dwm.music"}],
      centerBegin: [], center: [], centerEnd: [], tray: [],
      right: [
        {id: "dwm.status"}, {id: "dwm.divider",role:"status"},
        {id: "dwm.temperature"}, {id: "dwm.divider",role:"temperature"},
        {id: "omarchy.clock", format: "ddd dd MMM HH:mm", formatAlt: "dd MMM yyyy", showNextUp: false},
        {id: "dwm.divider"}, {id: "dwm.indicators"},
        {id: "omarchy.network"}, {id: "omarchy.bluetooth"},
        {id: "omarchy.audio"}, {id: "omarchy.power"},
        {id: "omarchy.keyboard-layout"}
      ].concat(configuredExtras, [{id:"dwm.tray"}, {id:"dwm.settings"}])
    })
    barConfigSerial++
  }
  Component.onCompleted: {
    bindRegistry()
    applyBarConfig()
  }
}
