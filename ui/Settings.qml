import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id:root
  moduleName:"dwm.settings"
  property QtObject telemetry:null
  property bool opened:false
  readonly property string monitorName:root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name:""
  visible:!telemetry || telemetry.modeFor(monitorName)!=="hidden"
  implicitWidth:button.implicitWidth
  implicitHeight:barSize
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("i18n")}
  function open(){opened=true}
  function close(){opened=false}
  function toggle(key){var patch={};patch[key]=!telemetry.settings[key];telemetry.save(patch)}
  function number(key,value){var patch={};patch[key]=value;telemetry.save(patch)}
  WidgetButton {id:button;bar:root.bar;text:"󰒓";pressScale:1;tooltipText:strings.t("settings");onPressed:root.opened=!root.opened}
  KeyboardPanel {
    id:panel
    anchorItem:button;owner:root;bar:root.bar;open:root.opened
    contentWidth:Style.space(440)
    contentHeight:Math.min(Style.space(640),availableCardHeight)
    QQC.ScrollView {
      anchors.fill:parent
      contentWidth:availableWidth
      clip:true
      Column {
        width:parent.width
        spacing:Style.space(8)
        PlainLabel {text:strings.t("settings");font.pixelSize:Style.font.title;font.bold:true}
        PlainLabel {visible:root.telemetry && root.telemetry.settingsError;text:strings.t("saveError");color:Commons.Color.urgent}
        Repeater {
          model:[{key:"gamingEfficiency",label:strings.t("gaming")},{key:"sleepAware",label:strings.t("sleep")},{key:"visualizer",label:strings.t("visualizer")},{key:"remoteArtwork",label:strings.t("remoteArt")}]
          Toggle {required property var modelData;width:parent.width;label:modelData.label;checked:root.telemetry?root.telemetry.settings[modelData.key]:false;onClicked:root.toggle(modelData.key)}
        }
        PlainLabel {width:parent.width;wrapMode:Text.WordWrap;text:strings.t("artHelp");font.pixelSize:Style.font.caption}
        Row {
          spacing:Style.space(12)
          NumberField {label:strings.t("cpuInterval");from:1;to:30;value:root.telemetry?root.telemetry.settings.fastInterval:2;onModified:function(value){root.number("fastInterval",value)}}
          NumberField {label:strings.t("gpuInterval");from:2;to:120;value:root.telemetry?root.telemetry.settings.gpuInterval:5;onModified:function(value){root.number("gpuInterval",value)}}
          NumberField {label:strings.t("musicWidth");from:120;to:480;stepSize:20;value:root.telemetry?root.telemetry.settings.musicWidth:240;onModified:function(value){root.number("musicWidth",value)}}
        }
        Row {
          spacing:Style.space(12)
          NumberField {label:strings.t("cpuWarn");from:1;to:100;value:root.telemetry?root.telemetry.settings.cpuWarn:90;onModified:function(value){root.number("cpuWarn",value)}}
          NumberField {label:strings.t("ramWarn");from:1;to:100;value:root.telemetry?root.telemetry.settings.ramWarn:90;onModified:function(value){root.number("ramWarn",value)}}
          NumberField {label:strings.t("gpuWarn");from:1;to:100;value:root.telemetry?root.telemetry.settings.gpuWarn:95;onModified:function(value){root.number("gpuWarn",value)}}
        }
        Row {
          spacing:Style.space(12)
          NumberField {label:strings.t("tempWarm");from:30;to:110;value:root.telemetry?root.telemetry.settings.tempWarm:75;onModified:function(value){root.number("tempWarm",value)}}
          NumberField {label:strings.t("tempHot");from:40;to:120;value:root.telemetry?root.telemetry.settings.tempHot:85;onModified:function(value){root.number("tempHot",value)}}
        }
        PlainLabel {text:strings.t("visible");font.bold:true}
        Flow {
          width:parent.width;spacing:Style.space(4)
          Repeater {
            model:[{key:"showCpu",label:"CPU"},{key:"showRam",label:"RAM"},{key:"showGpu",label:"GPU"},{key:"showVolume",label:"VOL"},{key:"showTemperature",label:"TEMP"},{key:"showMusic",label:strings.t("music")},{key:"showIndicators",label:strings.t("indicators")},{key:"showConnections",label:strings.t("connections")},{key:"showTray",label:strings.t("tray")}]
            Button {required property var modelData;text:modelData.label;selected:root.telemetry?root.telemetry.settings[modelData.key]:true;onClicked:root.toggle(modelData.key)}
          }
        }
        PlainLabel {text:strings.t("displays");font.bold:true}
        Repeater {
          model:Quickshell.screens
          Column {
            required property var modelData
            width:parent.width;spacing:Style.space(4)
            PlainLabel {text:modelData.name}
            Row {
              spacing:Style.space(4)
              Repeater {
                model:[{value:"full",label:strings.t("full")},{value:"minimal",label:strings.t("minimal")},{value:"hidden",label:strings.t("hidden")}]
                Button {
                  required property var modelData
                  property string output:parent.parent.modelData.name
                  text:modelData.label
                  selected:root.telemetry && root.telemetry.modeFor(output)===modelData.value
                  onClicked:root.telemetry.setMonitor(output,modelData.value)
                }
              }
            }
          }
        }
        PlainLabel {width:parent.width;wrapMode:Text.WordWrap;text:strings.t("displayHelp");font.pixelSize:Style.font.caption}
        PlainLabel {text:strings.t("classes")}
        TextField {
          width:parent.width
          text:root.telemetry?root.telemetry.settings.gameClasses.join(", "):""
          placeholderText:strings.t("classesHint")
          onEditingFinished:{
            var classes=text.split(",").map(function(v){return v.trim()}).filter(function(v){return v.length>0})
            if(JSON.stringify(classes)!==JSON.stringify(root.telemetry.settings.gameClasses))root.telemetry.save({gameClasses:classes})
          }
        }
        Button {text:strings.t("refresh");onClicked:root.telemetry.refreshHardware()}
      }
    }
  }
}
