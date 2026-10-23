import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../features/questions" as Questions

PanelWindow {
  id: panel
  required property var featureState
  property var screenSource: Quickshell
  property var monitorSource: Hyprland
  property bool ipcEnabled: true
  property var selectedScreen: null
  readonly property var availableScreens: screenSource ? screenSource.screens : []

  visible: false
  screen: selectedScreen
  color: "transparent"
  implicitWidth: Math.max(1, Math.min(820, screen ? screen.width - 48 : 820))
  implicitHeight: Math.max(1, Math.min(720, screen ? screen.height - 64 : 720))
  anchors { top: false; bottom: false; left: false; right: false }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omp-questions"
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function toggle(): void {
    if (visible) {
      hidePanel()
      return
    }
    const screens = availableScreens
    if (!screens || screens.length === 0) return
    const monitor = monitorSource ? monitorSource.focusedMonitor : null
    let targetScreen = screens[0]
    if (monitor) {
      for (let i = 0; i < screens.length; i++) {
        if (screens[i].name === monitor.name) {
          targetScreen = screens[i]
          break
        }
      }
    }
    selectedScreen = targetScreen
    visible = true
    Qt.callLater(function() {
      if (panel.visible) widget.focusInput()
    })
  }

  function hidePanel(): void {
    visible = false
  }

  function checkScreen(): void {
    if (!visible) return
    const screens = availableScreens
    if (selectedScreen && screens) {
      for (let i = 0; i < screens.length; i++) {
        if (screens[i] === selectedScreen) return
      }
    }
    hidePanel()
  }

  onAvailableScreensChanged: checkScreen()
  onSelectedScreenChanged: if (visible) checkScreen()

  IpcHandler {
    target: "questions"
    enabled: panel.ipcEnabled
    function toggle(): void { panel.toggle() }
  }

  Questions.Widget {
    id: widget
    anchors.fill: parent
    featureState: panel.featureState
    onCloseRequested: panel.hidePanel()
  }
}
