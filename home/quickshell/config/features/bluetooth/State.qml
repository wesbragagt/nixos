import QtQuick
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property bool powered: false
  function refresh() { return statusRunner.start(["bluetoothctl", "show"]) }
  Connections { target: state.statusRunner; function onCompleted(result) { state.powered = /Powered: yes/.test(result.stdout) } }
  Timer { interval: 2000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
