import QtQuick
import "../../shared" as Shared

Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property var mutationRunner: Shared.CommandRunner {}
  property string actionError: ""
  readonly property bool toggling: mutationRunner.busy
  property bool available: false
  property string activeState: "unknown"
  property string subState: ""
  readonly property bool running: activeState === "active" && subState === "running"

  function refresh() {
    return statusRunner.start(["systemctl", "show", "vanta.service", "--property=LoadState,ActiveState,SubState"])
  }

  function toggle() {
    if (!available || toggling) return false
    actionError = ""
    return mutationRunner.start(["sudo", "-n", "systemctl", running ? "stop" : "start", "vanta.service"])
  }

  Connections {
    target: state.mutationRunner
    function onCompleted(result) {
      state.actionError = result.failedToStart || result.exitCode !== 0
        ? (result.stderr.trim() || "Could not change Vanta service state.") : ""
      state.refresh()
    }
  }

  Connections {
    target: state.statusRunner
    function onCompleted(result) {
      if (result.failedToStart || result.exitCode !== 0) {
        state.activeState = "unknown"
        state.subState = ""
        return
      }
      const properties = {}
      for (const line of result.stdout.trim().split("\n")) {
        const separator = line.indexOf("=")
        if (separator > 0) properties[line.slice(0, separator)] = line.slice(separator + 1)
      }
      state.available = properties.LoadState !== undefined && properties.LoadState !== "not-found"
      state.activeState = properties.ActiveState || "unknown"
      state.subState = properties.SubState || ""
    }
  }

  Timer { interval: 2000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
