import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Button {
  id: root
  focusable: true
  foreground: Commons.Color.popups.text
  accent: Commons.Color.accent
  color: selected ? Qt.alpha(Commons.Color.accent, 0.3) : activeFocus ? Style.focusFillFor(foreground, accent) : hot ? Style.hoverFillFor(foreground, accent) : background
  Rectangle {
    visible: root.selected
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(root.borderBottom, Style.space(2))
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width / 3, Style.space(12))
    height: Style.space(2)
    color: Commons.Color.accent
  }
}
