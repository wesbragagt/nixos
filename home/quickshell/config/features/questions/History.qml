import QtQuick
import Quickshell
import "../../shared" as Shared

Item {
  id: history
  property var runner: Shared.CommandRunner {}
  property string sessionsDirectory: Quickshell.env("HOME") + "/.omp/agent/sessions/-"
  property var entries: []
  property string query: ""
  property bool busy: false
  property string error: ""
  readonly property var results: {
    const terms = query.toLowerCase().trim().split(/\s+/).filter(term => term.length > 0)
    return entries.filter(entry => {
      const text = (entry.question + "\n" + entry.answer).toLowerCase()
      return terms.every(term => text.indexOf(term) !== -1)
    })
  }

  function refresh() {
    if (busy) return false
    error = ""
    busy = true
    const helper = decodeURIComponent(Qt.resolvedUrl("HistoryLoader.mjs").toString().replace(/^file:\/\//, ""))
    if (!runner.start(["bun", helper, sessionsDirectory], "")) {
      busy = false
      error = "Saved history could not be loaded."
      return false
    }
    return true
  }

  Connections {
    target: history.runner
    function onCompleted(result) {
      if (!history.busy) return
      history.busy = false
      if (result.failedToStart || result.exitCode !== 0 || result.exitStatus !== 0) {
        history.entries = []
        history.error = "Saved history could not be read. Check session directory access and Bun availability."
        return
      }
      try {
        const loaded = JSON.parse(result.stdout)
        if (!Array.isArray(loaded) || !loaded.every(entry => entry
            && typeof entry.id === "string" && typeof entry.timestamp === "string"
            && typeof entry.question === "string" && typeof entry.answer === "string")) {
          throw new Error("Invalid history response")
        }
        history.entries = loaded
      } catch (_) {
        history.entries = []
        history.error = "Saved history returned an invalid response."
      }
    }
  }
}
