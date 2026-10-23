import QtQuick
import "../../shared" as Shared

Shared.Badge {
  id: widget
  required property var networkState
  required property var popupHostWindow
  readonly property bool focusRequired: popup.focusRequired
  property alias panel: popup
  icon: networkState.networkType === "ethernet" ? "\uf0e8" : networkState.networkType === "wifi" ? "\uf1eb" : "\uf071"
  accent: networkState.networkType ? Shared.Theme.green : Shared.Theme.pink
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.visible = !popup.visible
  }
  NetworkPanel {
    id: popup
    networkState: widget.networkState
    hostWindow: widget.popupHostWindow
    anchor.rect.x: widget.popupHostWindow ? Math.min(widget.popupHostWindow.width - width - 14, widget.mapToItem(widget.popupHostWindow.contentItem, 0, 0).x) : 0
    anchor.rect.y: widget.popupHostWindow ? widget.popupHostWindow.height + 8 : 0
  }
}
