import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  implicitWidth: Style.space(5)
  implicitHeight: barSize
  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: "|"
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    color: Commons.Color.bar.text
    opacity: 0.5
  }
}
