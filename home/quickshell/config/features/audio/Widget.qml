import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  icon: featureState.muted ? "\uf026" : "\uf028"
  value: featureState.muted ? "mute" : featureState.volume + "%"
  accent: Shared.Theme.yellow
  MouseArea {
    objectName: "audioActions"
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => { if (mouse.button === Qt.RightButton) featureState.toggleMute(); else featureState.openMixer() }
    onWheel: event => featureState.adjustVolume(event.angleDelta.y)
  }
}
