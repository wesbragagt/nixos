import QtQuick
import QtQuick.Controls

ScrollBar {
  policy: ScrollBar.AsNeeded
  contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.pressed }
}
