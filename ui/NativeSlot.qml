import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id:root
  property QtObject telemetry:null
  property Component sourceComponent:null
  property string role:"connections"
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name:""
  readonly property string mode:telemetry?telemetry.modeFor(monitorName):"full"
  visible:mode==="full" && (role==="clock" || !telemetry || (role==="plugins" ? (telemetry.settings.showPlugins && telemetry.pluginVisible(moduleName)) : telemetry.settings.showConnections))
  readonly property bool collapsed: !!telemetry && role!=="clock" && telemetry.compactFor(monitorName)
  opacity: collapsed ? 0 : 1
  // Effective visibility depends on the host slot having a nonzero width.
  // Checking it here creates a zero-width/hidden feedback loop at startup.
  // The native keyboard widget hides its label for a single layout, but its
  // implicit width still includes padding. Use its content state, not effective
  // visibility (which would reintroduce the startup sizing feedback loop).
  readonly property bool keyboardHasContent: moduleName!=="omarchy.keyboard-layout" || !content.item
    || !("inputLabel" in content.item) || !("multipleLayouts" in content.item)
    || (content.item.inputLabel!=="" && (content.item.multipleInputs || (content.item.layoutLabel!=="" && content.item.multipleLayouts)))
  readonly property bool keyboardAvailable: moduleName==="omarchy.keyboard-layout" && !!content.item && keyboardHasContent
  readonly property string keyboardLabel: moduleName==="omarchy.keyboard-layout" && content.item && "inputLabel" in content.item ? String(content.item.inputLabel).slice(0,32) : ""
  function reportKeyboard() {
    if(telemetry && moduleName==="omarchy.keyboard-layout")telemetry.reportKeyboard(monitorName,{available:keyboardAvailable,label:keyboardLabel})
  }
  onKeyboardAvailableChanged:reportKeyboard()
  onKeyboardLabelChanged:reportKeyboard()
  onMonitorNameChanged:reportKeyboard()
  onModuleNameChanged: {inject();reportKeyboard()}
  Component.onCompleted:reportKeyboard()
  Component.onDestruction:if(telemetry && moduleName==="omarchy.keyboard-layout")telemetry.reportKeyboard(monitorName,null)
  implicitWidth: collapsed || !keyboardHasContent ? 0 : content.item ? content.item.implicitWidth : 0
  implicitHeight:barSize
  readonly property bool opened:!!content.item && content.item.opened===true
  function open(){
    if(moduleName==="omarchy.keyboard-layout" && keyboardAvailable) {
      if(content.item.multipleInputs)InputMethodState.cycle()
      else if(content.item.multipleLayouts && content.item.cycleLayout)content.item.cycleLayout()
    } else if(content.item && content.item.open)content.item.open()
  }
  function close(){if(content.item && content.item.close)content.item.close()}
  function closeForPopoutSwitch(){if(content.item && content.item.closeForPopoutSwitch)content.item.closeForPopoutSwitch();else close()}
  function inject(){
    var target=content.item;if(!target)return
    target.bar=root.bar;target.moduleName=root.moduleName
    if("settings" in target)target.settings=root.settings
    if("fixedEdge" in target)target.fixedEdge=root.fixedEdge
  }
  onBarChanged:inject()
  onSettingsChanged:inject()
  onFixedEdgeChanged:inject()
  Loader {id:content;sourceComponent:root.sourceComponent;anchors.fill:parent;onLoaded:{root.inject();root.reportKeyboard()}}
}
