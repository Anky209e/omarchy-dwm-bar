import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id:root
  property QtObject telemetry:null
  property Component sourceComponent:null
  property string role:"connections"
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name:""
  readonly property string mode:telemetry?telemetry.modeFor(monitorName):"full"
  visible:mode==="full" && (role==="clock" || !telemetry || (role==="plugins" ? telemetry.settings.showPlugins : telemetry.settings.showConnections))
  implicitWidth:content.item && content.item.visible ? content.item.implicitWidth:0
  implicitHeight:barSize
  readonly property bool opened:!!content.item && content.item.opened===true
  function open(){if(content.item && content.item.open)content.item.open()}
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
  Loader {id:content;sourceComponent:root.sourceComponent;anchors.fill:parent;onLoaded:root.inject()}
}
