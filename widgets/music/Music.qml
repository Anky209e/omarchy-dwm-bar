import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dwm.music"
  readonly property var players: Mpris.players.values
  readonly property var player: {
    for (var i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
    for (var j = 0; j < players.length; j++) if (players[j].trackTitle) return players[j]
    return players.length ? players[0] : null
  }
  readonly property bool playing: !!player && player.isPlaying
  readonly property var screen: root.QsWindow.window ? root.QsWindow.window.screen : null
  implicitWidth: Style.space(screen && screen.width < 1800 ? 210 : 340)
  implicitHeight: barSize
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  ThemePalette { id: themePalette }
  WidgetButton {
    anchors.fill: parent
    bar: root.bar
    text: "music"
    labelVisible: false
    pressScale: 1
    tooltipText: strings.t("hint")
    onPressed: function(button) {
      if (!root.player) return
      if (button === Qt.RightButton) { if (root.player.canGoNext) root.player.next() }
      else if (button === Qt.MiddleButton) { if (root.player.canGoPrevious) root.player.previous() }
      else if (root.player.canTogglePlaying) root.player.togglePlaying()
    }
    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText
      elide: Text.ElideRight
      text: (root.playing ? "▶ " : "♫ ") + (!root.player ? strings.t("none") : root.player.trackArtist ? strings.t("track").arg(String(root.player.trackTitle || root.player.identity || "").slice(0,512)).arg(String(root.player.trackArtist).slice(0,256)) : String(root.player.trackTitle || root.player.identity || "").slice(0,512))
      color: root.playing ? Commons.Color.accent : themePalette.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
