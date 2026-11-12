import Quickshell
import Quickshell.Wayland
import QtQuick
import "../features/launcher" as Launcher
import "../features/system-metrics" as Metrics
import "../features/workspaces" as Workspaces
import "../features/audio" as Audio
import "../features/microphone" as Microphone
import "../features/idle" as Idle
import "../features/transcription" as Transcription
import "../features/dictation" as Dictation
import "../features/network" as Network
import "../features/bluetooth" as Bluetooth
import "../features/battery" as Battery
import "../features/clock" as Clock
import "../features/lock" as Lock
import "../features/vanta" as Vanta

PanelWindow {
  id: bar
  required property var launcherState
  required property var metricsState
  required property var workspacesState
  required property var audioState
  required property var microphoneState
  required property var idleState
  required property var transcriptionState
  required property var dictationState
  required property var networkState
  required property var bluetoothState
  required property var batteryState
  required property var clockState
  required property var lockState
  required property var vantaState

  WlrLayershell.keyboardFocus: (networkWidget.focusRequired || dictationWidget.focusRequired) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  anchors { top: true; left: true; right: true }
  implicitHeight: 32
  color: "transparent"

  Flickable {
    id: viewport
    anchors.fill: parent
    clip: true
    contentWidth: Math.max(width, leftSection.width + workspaceSection.width + rightSection.width + 68)
    contentHeight: height
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick

    WheelHandler {
      onWheel: event => {
        viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width,
          viewport.contentX - (event.angleDelta.x || event.angleDelta.y)))
        event.accepted = true
      }
    }

    Item {
      width: viewport.contentWidth
      height: viewport.height
  Row {
    id: leftSection
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    spacing: 20
    Launcher.Widget { featureState: bar.launcherState }
    Metrics.Widget { featureState: bar.metricsState }
    Battery.Widget { featureState: bar.batteryState }
  }

  Row {
    id: workspaceSection
    x: Math.max(leftSection.x + leftSection.width + 20,
      Math.min((parent.width - width) / 2, rightSection.x - width - 20))
    anchors.verticalCenter: parent.verticalCenter
    Workspaces.Widget { featureState: bar.workspacesState }
  }

  Row {
    id: rightSection
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    spacing: 20
    Audio.Widget { featureState: bar.audioState }
    Microphone.Widget { featureState: bar.microphoneState; popupHostWindow: bar }
    Idle.Widget { featureState: bar.idleState }
    Transcription.Widget { featureState: bar.transcriptionState }
    Dictation.Widget { id: dictationWidget; featureState: bar.dictationState; popupHostWindow: bar }
    Network.NetworkWidget {
      id: networkWidget
      networkState: bar.networkState
      popupHostWindow: bar
    }
    Bluetooth.Widget { featureState: bar.bluetoothState }
    Vanta.Widget { featureState: bar.vantaState }
    Clock.Widget { featureState: bar.clockState }
    Lock.Widget { featureState: bar.lockState }
  }
    }
  }
}
