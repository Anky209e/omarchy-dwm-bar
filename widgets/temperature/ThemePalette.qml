import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

QtObject {
  id: root
  property var values: ({})
  readonly property color green: readable(values.green || values.color2 || Commons.Color.accent)
  readonly property color blue: readable(values.blue || values.color4 || Commons.Color.accent)
  readonly property color magenta: readable(values.magenta || values.color5 || Commons.Color.accent)
  readonly property color cyan: readable(values.cyan || values.color6 || Commons.Color.accent)
  readonly property color yellow: readable(values.yellow || values.color3 || Commons.Color.accent)
  readonly property color red: readable(values.red || values.color1 || Commons.Color.urgent)
  readonly property color muted: readable(values.dark_foreground || values.color8 || Commons.Color.muted)
  function luminance(c) {
    function channel(v) { return v <= 0.04045 ? v/12.92 : Math.pow((v+0.055)/1.055,2.4) }
    return 0.2126*channel(c.r)+0.7152*channel(c.g)+0.0722*channel(c.b)
  }
  function readable(value) {
    var c=Qt.tint(value, "transparent"), bg=Commons.Color.background
    var a=luminance(c), b=luminance(bg)
    if((Math.max(a,b)+0.05)/(Math.min(a,b)+0.05)>=4.5)return c
    var target=b<0.179?Qt.rgba(1,1,1,1):Qt.rgba(0,0,0,1)
    for(var i=1;i<=20;i++) {
      var t=i/20, mixed=Qt.rgba(c.r+(target.r-c.r)*t,c.g+(target.g-c.g)*t,c.b+(target.b-c.b)*t,1)
      var l=luminance(mixed)
      if((Math.max(l,b)+0.05)/(Math.min(l,b)+0.05)>=4.5)return mixed
    }
    return target
  }
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
