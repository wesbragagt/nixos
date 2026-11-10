import QtQuick
import "../../shared" as Shared

Shared.Badge {
  required property var featureState
  visible: featureState.available
  icon: "\uf132"
  value: featureState.toggling ? "Vanta …" : featureState.running ? "Vanta on" : "Vanta off"
  accent: featureState.running ? Shared.Theme.green : Shared.Theme.yellow
  tooltipText: "Vanta service: " + featureState.activeState + "/" + featureState.subState
    + "\nService status only; not a compliance or registration check."
    + "\nClick to " + (featureState.running ? "stop" : "start") + " Vanta. Monitoring pauses while stopped."
    + (featureState.actionError ? "\n" + featureState.actionError : "")
  MouseArea {
    objectName: "toggle"
    anchors.fill: parent
    enabled: !featureState.toggling
    cursorShape: Qt.PointingHandCursor
    onClicked: featureState.toggle()
  }
}
