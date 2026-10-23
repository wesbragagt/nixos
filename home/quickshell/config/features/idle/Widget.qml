import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  icon: "\uf0f4"
  value: featureState.idleEnabled ? "idle" : "awake"
  accent: featureState.idleEnabled ? Shared.Theme.blue : Shared.Theme.green
  border.width: featureState.idleEnabled ? 0 : 1
  border.color: Shared.Theme.green
  MouseArea {
    objectName: "toggle"
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: featureState.toggle()
  }
}
