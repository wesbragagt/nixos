import QtQuick
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property var mutationRunner: Shared.CommandRunner {}
  property string status: "unavailable"
  property bool enabled: false
  property string preset: "Balanced"
  property string error: "Waiting for microphone service"
  property string source: ""
  readonly property bool busy: mutationRunner.busy
  property bool discardStatus: false
  function refresh() { return !busy && statusRunner.start(["mic-noise", "status"]) }
  function toggle() { return !busy && mutationRunner.start(["mic-noise", "toggle"]) }
  function setPreset(name) {
    if (["Light", "Balanced", "Strong"].indexOf(name) < 0) return false
    return !busy && mutationRunner.start(["mic-noise", "preset", name])
  }
  function restart() { return !busy && mutationRunner.start(["mic-noise", "restart"]) }
  function apply(result) {
    try {
      const data = JSON.parse(result.stdout)
      if (["starting", "running", "failed", "unavailable"].indexOf(data.status) < 0 || typeof data.enabled !== "boolean" || ["Light", "Balanced", "Strong"].indexOf(data.preset) < 0) throw new Error("Invalid microphone status")
      status = data.status
      enabled = data.enabled
      preset = data.preset
      error = data.commandError || data.error || ""
      source = data.source || ""
    } catch (e) {
      status = "unavailable"
      error = result.failedToStart ? "mic-noise command unavailable" : "Cannot read microphone status"
    }
  }
  Connections {
    target: state.statusRunner
    function onCompleted(result) {
      if (!state.busy && !state.discardStatus) state.apply(result)
      state.discardStatus = false
    }
  }
  Connections {
    target: state.mutationRunner
    function onStarted() { if (state.statusRunner.busy) state.discardStatus = true }
    function onCompleted(result) { state.apply(result) }
  }
  Timer { interval: 2000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
