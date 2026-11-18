import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../widgets/tray" as Tray

BarWidget {
  id:root
  moduleName:"dwm.overflow"
  property QtObject telemetry:null
  property var pluginEntries:[]
  property bool opened:false
  signal launch(string id,string monitor)
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen?root.QsWindow.window.screen.name:""
  visible:telemetry && telemetry.modeFor(monitorName)==="full" && telemetry.compactFor(monitorName)
  readonly property int openPanelIndicatorWidth:Style.space(12)
  implicitWidth:Style.bar.statusSlot
  implicitHeight:barSize
  function open(){opened=true}
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
    anchorItem:button;bar:root.bar;owner:root;open:root.opened
    contentWidth:Style.space(330)
    contentHeight:fittedContentHeight(Math.min(Style.space(550),column.implicitHeight))
    focusTarget:column
    QQC.ScrollView {
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
      Repeater {
        model:(root.telemetry && root.telemetry.settings.showConnections?[{id:"omarchy.network",label:strings.t("network")},{id:"omarchy.bluetooth",label:"Bluetooth"},{id:"omarchy.audio",label:strings.t("audio")},{id:"omarchy.power",label:strings.t("power")}]:[]).concat(root.telemetry && root.telemetry.settings.showPlugins?root.pluginEntries.filter(function(e){return root.telemetry.pluginVisible(e.id)}):[])
        StateButton {
          required property var modelData
          width:parent.width
          text:modelData.label || (modelData.id==="omarchy.agents"?strings.t("agents"):modelData.id==="crmne.hyprmoncfg"?strings.t("displays"):modelData.id)
          onClicked:{root.close();root.launch(modelData.id,root.monitorName)}
        }
      }
      PlainLabel {visible:root.telemetry && root.telemetry.settings.showTray;text:strings.t("trayItems");font.bold:true}
      Tray.Tray {bar:root.bar;telemetry:root.telemetry;inDrawer:true;settings:({});width:Math.min(implicitWidth,column.width);height:implicitHeight}
    }
    }
  }
}
