import QtQuick
import Quickshell
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property bool featureEnabled: Quickshell.env("QUICKSHELL_TRANSCRIBE") === "1"
  property var statusRunner: Shared.CommandRunner {}
  property var mutationRunner: Shared.CommandRunner {}
  property string transcriptionState: "unknown"
  function refresh() { return featureEnabled && statusRunner.start(["transcribe", "status"]) }
  function toggle() { return featureEnabled && mutationRunner.start(["transcribe", "toggle"]) }
  Connections {
    target: state.statusRunner
    function onCompleted(result) {
      if (result.exitCode !== 0) state.transcriptionState = "unknown"
      else state.transcriptionState = JSON.parse(result.stdout).class
    }
  }
  Connections { target: state.mutationRunner; function onCompleted(result) { state.refresh() } }
  Timer { interval: 2000; running: state.pollingEnabled && state.featureEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled && featureEnabled) refresh()
}
