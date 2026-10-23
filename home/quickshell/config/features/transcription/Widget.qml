import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  visible: featureState.featureEnabled
  icon: featureState.transcriptionState === "disabled" ? "\uf131" : "\uf130"
  value: featureState.transcriptionState === "recording" ? "REC" : featureState.transcriptionState === "enabled" ? "auto" : featureState.transcriptionState === "disabled" ? "off" : "?"
  accent: featureState.transcriptionState === "recording" ? Shared.Theme.pink : featureState.transcriptionState === "enabled" ? Shared.Theme.green : Shared.Theme.muted
  border.width: featureState.transcriptionState === "recording" ? 1 : 0
  border.color: Shared.Theme.pink
  MouseArea {
    objectName: "toggle"
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: featureState.toggle()
  }
}
