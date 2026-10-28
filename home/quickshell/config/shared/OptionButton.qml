import QtQuick
import QtQuick.Controls

// Themed button; `selected` marks the active choice in an option group.
Button {
  id: control
  property bool selected: false
  implicitHeight: 30
  leftPadding: 12
  rightPadding: 12
  contentItem: Text {
    text: control.text
    color: control.selected ? Theme.block : control.enabled ? Theme.foreground : Theme.muted
    font { family: Theme.fontFamily; pixelSize: Theme.smallFontSize; bold: control.selected }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  background: Rectangle {
    radius: 6
    color: control.selected ? Theme.blue : control.down ? Theme.pressed : control.hovered ? Theme.hover : Theme.surface
    border.color: control.selected ? Theme.blue : Theme.hover
  }
}
