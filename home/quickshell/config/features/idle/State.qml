import QtQuick
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property var mutationRunner: Shared.CommandRunner {}
  property bool idleEnabled: true
  function refresh() { return statusRunner.start(["idle-control", "status"]) }
  function toggle() { return mutationRunner.start(["idle-control", "toggle"]) }
  Connections {
    target: state.statusRunner
    function onCompleted(result) { state.idleEnabled = JSON.parse(result.stdout).class === "enabled" }
  }
  Connections { target: state.mutationRunner; function onCompleted(result) { state.refresh() } }
  Timer { interval: 2000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
