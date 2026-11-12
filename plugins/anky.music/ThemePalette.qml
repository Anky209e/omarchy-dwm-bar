import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

QtObject {
  id: root
  property var values: ({})
  readonly property color green: values.green || values.color2 || Commons.Color.accent
  readonly property color blue: values.blue || values.color4 || Commons.Color.accent
  readonly property color magenta: values.magenta || values.color5 || Commons.Color.accent
  readonly property color cyan: values.cyan || values.color6 || Commons.Color.accent
  readonly property color yellow: values.yellow || values.color3 || Commons.Color.accent
  readonly property color red: values.red || values.color1 || Commons.Color.urgent
  readonly property color muted: values.dark_foreground || values.color8 || Commons.Color.muted
  function parse(raw) {
    var next = {}
    var lines = String(raw).slice(0, 65536).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["'](#[0-9a-fA-F]{6})["']/)
      if (match) next[match[1]] = match[2]
    }
    values = next
  }
  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.parse(text())
    onFileChanged: reload()
  }
  property Connections themeChanges: Connections {
    target: Commons.Color
    function onAccentChanged() { root.file.reload() }
    function onBackgroundChanged() { root.file.reload() }
    function onForegroundChanged() { root.file.reload() }
  }
}
