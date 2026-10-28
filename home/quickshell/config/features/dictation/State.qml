import QtQuick
import Quickshell
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property bool featureEnabled: Quickshell.env("QUICKSHELL_DICTATE") === "1"
  property var statusRunner: Shared.CommandRunner {}
  property var mutationRunner: Shared.CommandRunner {}
  readonly property var languages: ["auto", "en", "de", "fr", "es", "it", "nl", "pl"]
  readonly property bool busy: mutationRunner.busy
  property bool discardStatus: false
  property bool available: false
  property bool recording: false
  property string language: "auto"
  property string depth: "full"
  property string insert: "type"
  property string mic: "default"
  property var mics: []
  property var keywords: []
  property var history: []
  function refresh() { return featureEnabled && !busy && statusRunner.start(["dictate", "status"]) }
  function setOption(key, value) { return !busy && mutationRunner.start(["dictate", "set", key, String(value)]) }
  // Keywords travel on stdin so long vocabularies never hit argv limits.
  function setKeywords(text) { return !busy && mutationRunner.start(["dictate", "keywords"], text) }
  function apply(result) {
    try {
      const data = JSON.parse(result.stdout)
      if (["idle", "recording"].indexOf(data.state) < 0) throw new Error("Invalid dictate status")
      recording = data.state === "recording"
      language = data.language
      depth = data.depth
      insert = data.insert
      mic = data.mic
      mics = data.mics || []
      keywords = data.keywords || []
      history = data.history || []
      available = true
    } catch (e) {
      available = false
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
    function onCompleted(result) {
      if (result.exitCode === 0) state.apply(result)
      else state.refresh()
    }
  }
  Timer { interval: 2000; running: state.pollingEnabled && state.featureEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled && featureEnabled) refresh()
}
