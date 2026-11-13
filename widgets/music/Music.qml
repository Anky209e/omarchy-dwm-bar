import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../../ui"

BarWidget {
  id:root
  moduleName:"dwm.music"
  property QtObject telemetry:null
  property bool opened:false
  property real position:0
  readonly property var player:telemetry?telemetry.player:null
  readonly property bool repeatTrack:!!player && player.loopState===MprisLoopState.Track
  readonly property bool playing:!!player && player.isPlaying
  readonly property var screen:root.QsWindow.window?root.QsWindow.window.screen:null
  readonly property string monitorName:screen?screen.name:"music"
  readonly property string title:player?String(player.trackTitle || player.identity || "").slice(0,512):strings.t("none")
  readonly property string artist:player?String(player.trackArtist || "").slice(0,256):""
  readonly property string album:player?String(player.trackAlbum || "").slice(0,256):""
  visible:!telemetry || (telemetry.modeFor(monitorName)!=="hidden" && telemetry.settings.showMusic)
  implicitWidth:Style.space(Math.min(telemetry?telemetry.settings.musicWidth:240,screen && screen.width<1800?210:480))
  implicitHeight:barSize
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("i18n")}
  ThemePalette {id:themePalette}
  component TransportButton: Button {
    property bool primary: false
    width: Style.space(primary ? 64 : 44)
    height: Style.space(44)
    horizontalPadding: 0
    verticalPadding: 0
    iconSize: primary ? Style.font.iconLarge : Style.font.icon
    opacity: enabled ? 1 : 0.35
  }
  function open(){opened=true}
  function close(){opened=false}
  function playPause(){if(player && player.canTogglePlaying)player.togglePlaying()}
  function timeLabel(seconds){var n=Math.max(0,Math.floor(Number(seconds)||0));return Commons.I18n.formatNumber(Math.floor(n/60))+":"+Commons.I18n.formatNumber(n%60).padStart(2,Commons.I18n.formatNumber(0))}
  function toggleLoop(){if(player && player.loopSupported)player.loopState=player.loopState===MprisLoopState.None?MprisLoopState.Playlist:player.loopState===MprisLoopState.Playlist?MprisLoopState.Track:MprisLoopState.None}
  onPlayerChanged:position=player && player.positionSupported?player.position:0
  Connections {target:root.player;ignoreUnknownSignals:true;function onPositionChanged(){if(root.opened && !progress.dragging && root.player)root.position=root.player.position}}
  onOpenedChanged:{if(telemetry)telemetry.setMusicOpen(monitorName,opened);if(player)position=player.position}
  onVisibleChanged:if(!visible)close()
  Component.onDestruction:if(telemetry)telemetry.setMusicOpen(monitorName,false)
  Timer {interval:1000;running:root.opened && root.playing;repeat:true;onTriggered:if(root.player)root.position=root.player.position}
  WidgetButton {
    id:button
    anchors.fill:parent
    bar:root.bar;text:"music";labelVisible:false;pressScale:1
    tooltipText:strings.t("hint")
    onPressed:function(mouseButton){if(mouseButton===Qt.RightButton)root.playPause();else if(mouseButton===Qt.MiddleButton){if(root.player && root.player.canGoNext)root.player.next()}else root.opened=!root.opened}
    Text {
      anchors.fill:parent;anchors.leftMargin:Style.space(6);anchors.rightMargin:Style.space(6)
      verticalAlignment:Text.AlignVCenter;textFormat:Text.PlainText;elide:Text.ElideRight
      text:(root.playing?"󰐊 ":"󰝚 ")+(root.artist?strings.t("track").arg(root.title).arg(root.artist):root.title)
      color:root.playing?Commons.Color.accent:themePalette.muted
      font.family:Style.font.family;font.pixelSize:Style.font.body
    }
  }
  KeyboardPanel {
    id:panel
    anchorItem:button;owner:root;bar:root.bar;open:root.opened
    contentWidth:Style.space(400)
    contentHeight:fittedContentHeight(column.implicitHeight)
    Column {
      id:column
      width:parent.width
      spacing:Style.space(12)
      Row {
        width:parent.width
        PlainLabel {width:parent.width-Style.space(36);anchors.verticalCenter:parent.verticalCenter;text:strings.t("nowPlaying");font.pixelSize:Style.font.title;font.bold:true}
        Button {width:Style.space(32);height:Style.space(30);horizontalPadding:0;verticalPadding:0;iconText:"󰅖";tooltipText:strings.t("close");onClicked:root.close()}
      }
      Row {
        width:parent.width;spacing:Style.space(12)
        Rectangle {
          width:Style.space(110);height:width;color:Commons.Color.menu.selectedBackground
          Image {anchors.fill:parent;source:root.opened && root.telemetry?root.telemetry.artSource:"";sourceSize.width:220;sourceSize.height:220;fillMode:Image.PreserveAspectFit;asynchronous:true}
          PlainLabel {anchors.centerIn:parent;visible:!root.telemetry || root.telemetry.artSource==="";text:"󰝚";font.pixelSize:Style.font.displayLarge;color:Commons.Color.accent}
        }
        Column {
          width:parent.width-Style.space(122);spacing:Style.space(5)
          PlainLabel {width:parent.width;text:root.title;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font.bold:true;font.pixelSize:Style.font.subtitle}
          PlainLabel {width:parent.width;text:root.artist;elide:Text.ElideRight;color:Commons.Color.popups.text;opacity:0.65}
          PlainLabel {width:parent.width;text:root.album;elide:Text.ElideRight;font.pixelSize:Style.font.caption}
          PlainLabel {width:parent.width;visible:root.telemetry && root.telemetry.artState==="blocked";text:strings.t("artBlocked");wrapMode:Text.WordWrap;font.pixelSize:Style.font.caption}
        }
      }
      Item {
        width:parent.width;height:Style.space(30)
        visible:root.telemetry && root.telemetry.settings.visualizer
        Row {
          anchors.fill:parent;spacing:Style.space(3)
          Repeater {
            model:16
            Rectangle {
              required property int index
              width:(parent.width-Style.space(3)*15)/16
              height:Math.max(Style.space(2),(root.telemetry && root.telemetry.spectrum[index] || 0)*parent.height)
              anchors.bottom:parent.bottom
              color:index%2===0?Commons.Color.accent:themePalette.cyan
              opacity:root.playing?0.9:0.3
              Behavior on height {NumberAnimation {duration:Style.duration(70);easing.type:Easing.OutCubic}}
            }
          }
        }
        PlainLabel {anchors.centerIn:parent;visible:root.telemetry && root.telemetry.spectrumState==="unavailable";text:strings.t("vizUnavailable");font.pixelSize:Style.font.caption}
      }
      PanelSlider {
        id:progress
        width:parent.width;bar:root.bar
        minimum:0;maximum:root.player && root.player.lengthSupported?Math.max(1,root.player.length):1
        value:root.player && root.player.lengthSupported && root.player.length>0?Math.min(maximum,root.position):0
        enabled:root.player && root.player.canSeek && root.player.positionSupported && root.player.lengthSupported && root.player.length>0
        onReleased:function(value){if(root.player && root.player.canSeek){root.position=value;root.player.position=value}}
      }
      Row {
        width:parent.width
        PlainLabel {width:parent.width/2;text:root.timeLabel(root.position);font.pixelSize:Style.font.caption}
        PlainLabel {width:parent.width/2;horizontalAlignment:Text.AlignRight;text:root.player && root.player.lengthSupported && root.player.length>0?root.timeLabel(root.player.length):"—:—";font.pixelSize:Style.font.caption}
      }
      Row {
        anchors.horizontalCenter:parent.horizontalCenter
        spacing:Style.space(8)
        layoutDirection:Qt.LeftToRight
        TransportButton {
          iconText:"󰒝"
          tooltipText:strings.t("shuffle")
          enabled:root.player && root.player.shuffleSupported
          selected:root.player && root.player.shuffle
          onClicked:root.player.shuffle=!root.player.shuffle
        }
        TransportButton {
          iconText:"󰒮"
          tooltipText:strings.t("previous")
          enabled:root.player && root.player.canGoPrevious
          onClicked:root.player.previous()
        }
        TransportButton {
          primary:true
          iconText:root.playing?"󰏤":"󰐊"
          tooltipText:root.playing?strings.t("pause"):strings.t("play")
          enabled:root.player && root.player.canTogglePlaying
          selected:root.playing
          onClicked:root.playPause()
        }
        TransportButton {
          iconText:"󰒭"
          tooltipText:strings.t("next")
          enabled:root.player && root.player.canGoNext
          onClicked:root.player.next()
        }
        TransportButton {
          iconText:root.repeatTrack?"󰑘":"󰑖"
          tooltipText:root.repeatTrack?strings.t("repeatTrack"):strings.t("repeat")
          enabled:root.player && root.player.loopSupported
          selected:root.player && root.player.loopState!==MprisLoopState.None
          onClicked:root.toggleLoop()
        }
      }
      PanelSeparator { foreground:Commons.Color.popups.text }
      PlainLabel {visible:root.telemetry && root.telemetry.players.length>1;text:strings.t("players");font.bold:true}
      Repeater {
        model:root.telemetry?root.telemetry.players.slice(0,8):[]
        Button {
          required property var modelData
          width:parent.width
          iconText:"󰀻"
          text:String(modelData.identity || modelData.desktopEntry || strings.t("player")).slice(0,80)
          selected:root.player===modelData
          onClicked:root.telemetry.selectedPlayer=modelData
        }
      }
      Row {
        width:parent.width
        spacing:Style.space(8)
        Button {
          width:(parent.width-Style.space(8))/2
          iconText:"󰺢"
          text:strings.t("visualizer")
          tooltipText:strings.t("visualizerHelp")
          selected:root.telemetry && root.telemetry.settings.visualizer
          onClicked:root.telemetry.save({visualizer:!root.telemetry.settings.visualizer})
        }
        Button {
          width:(parent.width-Style.space(8))/2
          iconText:"󰋩"
          text:strings.t("artwork")
          tooltipText:strings.t("artworkHelp")
          selected:root.telemetry && root.telemetry.settings.remoteArtwork
          onClicked:root.telemetry.save({remoteArtwork:!root.telemetry.settings.remoteArtwork})
        }
      }
    }
  }
}
