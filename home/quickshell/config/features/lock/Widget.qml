import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  icon: "\uf011"
  accent: Shared.Theme.pink
  horizontalPadding: 10
  MouseArea {
    objectName: "action"
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: featureState.lock()
  }
}
