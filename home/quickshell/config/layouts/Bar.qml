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
import "../features/clock" as Clock
import "../features/lock" as Lock

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
  required property var clockState
  required property var lockState

  WlrLayershell.keyboardFocus: (networkWidget.focusRequired || dictationWidget.focusRequired) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  anchors { top: true; left: true; right: true }
  implicitHeight: 32
  color: "transparent"

  Row {
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    spacing: 20
    Launcher.Widget { featureState: bar.launcherState }
    Metrics.Widget { featureState: bar.metricsState }
  }

  Row {
    anchors.centerIn: parent
    spacing: 0
    Workspaces.Widget { featureState: bar.workspacesState }
  }

  Row {
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
    Clock.Widget { featureState: bar.clockState }
    Lock.Widget { featureState: bar.lockState }
  }
}
