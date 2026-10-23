import Quickshell
import "layouts" as Layouts
import "features/launcher" as Launcher
import "features/system-metrics" as Metrics
import "features/workspaces" as Workspaces
import "features/audio" as Audio
import "features/microphone" as Microphone
import "features/idle" as Idle
import "features/transcription" as Transcription
import "features/network" as Network
import "features/bluetooth" as Bluetooth
import "features/clock" as Clock
import "features/lock" as Lock
import "features/questions" as Questions

ShellRoot {
  Launcher.State { id: launcher }
  Metrics.State { id: metrics }
  Workspaces.State { id: workspaces }
  Audio.State { id: audio }
  Microphone.State { id: microphone }
  Idle.State { id: idle }
  Transcription.State { id: transcription }
  Network.NetworkState { id: network }
  Bluetooth.State { id: bluetooth }
  Clock.State { id: clock }
  Lock.State { id: lock }
  Questions.State { id: questions }
  Layouts.Questions { featureState: questions }

  Variants {
    model: Quickshell.screens

    Layouts.Bar {
      required property var modelData
      screen: modelData
      launcherState: launcher
      metricsState: metrics
      workspacesState: workspaces
      audioState: audio
      microphoneState: microphone
      idleState: idle
      transcriptionState: transcription
      networkState: network
      bluetoothState: bluetooth
      clockState: clock
      lockState: lock
    }
  }
}
