import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../shared" as Shared

Shared.Badge {
  id: widget
  required property var featureState
  required property var popupHostWindow
  icon: "\uf130"
  value: featureState.status !== "running" ? "error" : featureState.enabled ? "clean" : "raw"
  accent: featureState.status !== "running" ? Shared.Theme.pink : featureState.enabled ? Shared.Theme.green : Shared.Theme.muted
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.visible = !popup.visible
  }
  PopupWindow {
    id: popup
    anchor.window: widget.popupHostWindow
    anchor.rect.x: widget.popupHostWindow ? Math.max(0, Math.min(widget.popupHostWindow.width - width - 14, widget.mapToItem(widget.popupHostWindow.contentItem, 0, 0).x)) : 0
    anchor.rect.y: widget.popupHostWindow ? widget.popupHostWindow.height + 8 : 0
    implicitWidth: 330
    implicitHeight: content.implicitHeight + 32
    color: "transparent"
    onVisibleChanged: {
      if (visible) { widget.featureState.refresh(); focusTimer.start() }
      else { focusTimer.stop(); focusGrab.active = false }
    }
    HyprlandFocusGrab {
      id: focusGrab
      windows: [popup, widget.popupHostWindow]
      onCleared: popup.visible = false
    }
    Timer { id: focusTimer; interval: 150; onTriggered: if (popup.visible) focusGrab.active = true }
    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Shared.Theme.block
      ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10
        Text { text: "Microphone noise suppression"; color: Shared.Theme.foreground; font.family: Shared.Theme.fontFamily; font.pixelSize: Shared.Theme.fontSize }
        Text {
          Layout.fillWidth: true
          text: widget.featureState.error || (widget.featureState.enabled ? "Filtered audio · " + widget.featureState.preset : "Bypass · unfiltered microphone audio")
          wrapMode: Text.Wrap
          color: widget.featureState.error ? Shared.Theme.pink : Shared.Theme.foreground
          font.family: Shared.Theme.fontFamily
          font.pixelSize: Shared.Theme.smallFontSize
        }
        Shared.OptionButton {
          text: widget.featureState.enabled ? "Use raw microphone" : "Enable suppression"
          enabled: !widget.featureState.busy && widget.featureState.status === "running"
          onClicked: widget.featureState.toggle()
        }
        RowLayout {
          Repeater {
            model: ["Light", "Balanced", "Strong"]
            Shared.OptionButton {
              required property string modelData
              text: modelData
              selected: widget.featureState.preset === modelData
              enabled: !widget.featureState.busy && widget.featureState.status === "running"
              onClicked: widget.featureState.setPreset(modelData)
            }
          }
        }
        Text {
          text: "Select CleanMicrophone in your calling app."
          Layout.fillWidth: true
          wrapMode: Text.Wrap
          color: Shared.Theme.muted
          font.family: Shared.Theme.fontFamily
          font.pixelSize: Shared.Theme.smallFontSize
        }
        Shared.OptionButton { text: "Restart processor"; enabled: !widget.featureState.busy; onClicked: widget.featureState.restart() }
      }
    }
  }
}
