import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../widgets/tray" as Tray
import "../widgets/tray/TrayModel.js" as TrayModel

BarWidget {
  id:root
  moduleName:"dwm.overflow"
  property QtObject telemetry:null
  property var pluginEntries:[]
  property bool opened:false
  signal launch(string id,string monitor)
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen?root.QsWindow.window.screen.name:""
  readonly property var keyboard:telemetry && telemetry.keyboards[monitorName] ? telemetry.keyboards[monitorName] : ({available:false,label:""})
  readonly property var extraControls:telemetry && telemetry.settings.showPlugins?pluginEntries.filter(function(e){return telemetry.pluginVisible(e.id)}):[]
  readonly property bool hasTrayItems: {
    if(!telemetry || !telemetry.settings.showTray)return false
    var items=SystemTray.items.values
    for(var i=0;i<items.length;i++)if(items[i].status!==Status.Passive && !TrayModel.ownedByOmarchy(items[i],root.bar?root.bar.layoutConfig:null))return true
    return false
  }
  readonly property bool hasControls:!!telemetry && (telemetry.settings.showIndicators || telemetry.settings.showConnections || extraControls.length>0 || hasTrayItems)
  visible:telemetry && telemetry.modeFor(monitorName)==="full" && telemetry.compactFor(monitorName) && hasControls
  readonly property int openPanelIndicatorWidth:Style.space(12)
  implicitWidth:Style.bar.statusSlot
  implicitHeight:barSize
  function open(){if(visible)opened=true}
  function close(){opened=false}
  onVisibleChanged:if(!visible)close()
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("i18n")}
  WidgetButton {
    id:button
    anchors.fill:parent
    fixedWidth:Style.bar.statusSlot
    fixedHeight:root.barSize
    bar:root.bar;text:"󰇘";labelVisible:false;pressScale:1
    active:root.opened;activeColor:Commons.Color.accent
    tooltipText:strings.t("overflow")
    onPressed:root.opened=!root.opened
    Row {
      anchors.centerIn:parent
      spacing:Style.space(3)
      Repeater {
        model:3
        Rectangle {
          width:Style.space(2);height:width;radius:width/2
          color:root.opened?Commons.Color.accent:Commons.Color.bar.text
        }
      }
    }
  }
  KeyboardPanel {
    id:panel
    anchorItem:button;bar:root.bar;owner:root;open:root.opened
    contentWidth:Style.space(330)
    contentHeight:fittedContentHeight(panel.loadedContentHeight)
    focusTarget:panel.loadedContent ? panel.loadedContent.focusItem : null
    content: Component {
    QQC.ScrollView {
      property alias focusItem:column
      implicitHeight:Math.min(Style.space(550),column.implicitHeight)
      width:parent.width;height:Math.min(Style.space(550),column.implicitHeight)
      contentWidth:availableWidth;clip:true
    Column {
      id:column;width:parent.width;spacing:Style.space(8)
      Keys.onEscapePressed:root.close()
      PlainLabel {text:strings.t("overflow");font.bold:true}
      Grid {
        width:parent.width;columns:2;spacing:Style.space(6)
        Repeater {
          model:root.telemetry && root.telemetry.settings.showIndicators?[{id:"awake",icon:""},{id:"night",icon:"󰔎"},{id:"recording",icon:"󰻂"},{id:"dnd",icon:"󰂛"}]:[]
          StateButton {
            required property var modelData
            width:(parent.width-Style.space(6))/2
            iconText:modelData.icon
            text:strings.t("state."+modelData.id)
            selected:root.telemetry && root.telemetry.state[modelData.id]
            onClicked:{if(modelData.id==="awake")root.telemetry.toggleIdle();else if(modelData.id==="night")root.telemetry.toggleNight();else if(modelData.id==="dnd")root.telemetry.toggleDnd();else {root.close();root.telemetry.record()}}
          }
        }
      }
      StateButton {
        visible:root.telemetry && root.telemetry.settings.showConnections && root.keyboard.available
        width:parent.width
        iconText:"󰌌"
        text:strings.t("keyboard").arg(root.keyboard.label)
        tooltipText:strings.t("keyboardHelp")
        onClicked:root.launch("omarchy.keyboard-layout",root.monitorName)
      }
      Repeater {
        model:(root.telemetry && root.telemetry.settings.showConnections?[{id:"omarchy.network",label:strings.t("network")},{id:"omarchy.bluetooth",label:"Bluetooth"},{id:"omarchy.audio",label:strings.t("audio")},{id:"omarchy.power",label:strings.t("power")}]:[]).concat(root.extraControls)
        StateButton {
          required property var modelData
          width:parent.width
          text:modelData.label || (modelData.id==="omarchy.agents"?strings.t("agents"):modelData.id==="crmne.hyprmoncfg"?strings.t("displays"):modelData.id)
          onClicked:{root.close();root.launch(modelData.id,root.monitorName)}
        }
      }
      PlainLabel {visible:root.hasTrayItems;text:strings.t("trayItems");font.bold:true}
      Tray.Tray {bar:root.bar;telemetry:root.telemetry;inDrawer:true;settings:({});width:Math.min(implicitWidth,column.width);height:implicitHeight}
    }
    }
    }
  }
}
