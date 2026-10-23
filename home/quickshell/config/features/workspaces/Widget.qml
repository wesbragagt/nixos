import QtQuick
import "../../shared" as Shared
Rectangle {
  id: widget
  required property var featureState
  implicitWidth: row.implicitWidth + 16
  implicitHeight: 24
  radius: 5
  color: Shared.Theme.block
  Row {
    id: row
    anchors.centerIn: parent
    spacing: 4
    Repeater {
      model: widget.featureState.workspaces
      Rectangle {
        required property var modelData
        readonly property bool active: widget.featureState.focusedWorkspace === modelData
        objectName: "workspace-" + modelData.name
        width: 42
        height: 24
        radius: 4
        color: active ? Shared.Theme.hover : "transparent"
        Shared.Label {
          anchors.centerIn: parent
          text: modelData.name
          color: parent.active ? Shared.Theme.focusedWorkspace : Shared.Theme.foreground
        }
        MouseArea {
          objectName: "activate"
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: widget.featureState.activate(modelData)
        }
      }
    }
  }
}
