import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  icon: "\uf313"
  accent: Shared.Theme.launcher
  horizontalPadding: 12
  MouseArea {
    objectName: "action"
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: featureState.launch()
  }
}
