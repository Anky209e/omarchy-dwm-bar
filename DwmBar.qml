import QtQuick
import qs.Commons
import "services" as Services
import "file:/usr/share/omarchy/shell/plugins/bar" as OmarchyBar
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
    gamingEnabled: root.barConfig.gamingEfficiency !== false
    extraGameClasses: root.barConfig.gameClasses || []
  }

  Component { id: tags; Tags.Workspaces {} }
  Component { id: music; Music.Music {} }
  Component { id: status; Status.Status { telemetry: sharedTelemetry } }
  Component { id: temperature; Temperature.Temperature { telemetry: sharedTelemetry } }
  Component { id: indicators; Indicators.Indicators { telemetry: sharedTelemetry } }
  Component { id: divider; Divider.Divider {} }
  Component { id: tray; Tray.Tray {} }

  readonly property var internalComponents: ({
    "dwm.workspaces": tags,
    "dwm.music": music,
    "dwm.status": status,
    "dwm.temperature": temperature,
    "dwm.indicators": indicators,
    "dwm.divider": divider,
    "dwm.tray": tray
  })

  QtObject {
    id: bundledRegistry
    readonly property int revision: root.inheritedRegistry ? root.inheritedRegistry.revision : 0
    readonly property var widgets: {
      var result = {}
      var nativeWidgets = root.inheritedRegistry ? root.inheritedRegistry.widgets : {}
      for (var name in nativeWidgets) result[name] = nativeWidgets[name]
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
        {id: "dwm.status"}, {id: "dwm.divider"},
        {id: "dwm.temperature"}, {id: "dwm.divider"},
        {id: "omarchy.clock", format: "ddd dd MMM HH:mm", formatAlt: "dd MMM yyyy", showNextUp: false},
        {id: "dwm.divider"}, {id: "dwm.indicators"},
        {id: "omarchy.network"}, {id: "omarchy.bluetooth"},
        {id: "omarchy.audio"}, {id: "omarchy.power"},
        {id: "omarchy.keyboard-layout"}, {id: "dwm.tray"}
      ]
    })
    barConfigSerial++
  }
  Component.onCompleted: {
    bindRegistry()
    applyBarConfig()
  }
}
