import QtQuick
import Quickshell.Io

QtObject {
  id: runner
  // Environment is inherited, with an English parsing locale. Per-call values win.
  property var environment: ({ LC_ALL: "C.UTF-8" })
  readonly property bool busy: internal.active
  signal started()
  signal completed(var result)
  signal detachedRequested()

  // Accepted work is never restarted. Input is transient and never part of a result.
  function start(argv, input, overrides) {
    if (busy || !argv || argv.length === 0) return false
    internal.active = true
    internal.didStart = false
    internal.stdoutText = ""
    internal.stderrText = ""
    internal.input = input === undefined ? "" : input
    process.environment = Object.assign({}, environment, overrides || {})
    process.command = argv
    process.stdinEnabled = true
    process.running = true
    return true
  }

  // Process.startDetached() has no success/exit result in Quickshell 0.2.1.
  // true means request submitted, not that the child started or succeeded.
  function launchDetached(argv, overrides) {
    if (busy || !argv || argv.length === 0) return false
    process.environment = Object.assign({}, environment, overrides || {})
    process.command = argv
    process.startDetached()
    detachedRequested()
    return true
  }

  property QtObject internal: QtObject {
    property bool active: false
    property bool didStart: false
    property string input: ""
    property string stdoutText: ""
    property string stderrText: ""
  }

  function finish(code, status, failedToStart) {
    if (!busy) return
    internal.input = ""
    const result = { stdout: internal.stdoutText, stderr: internal.stderrText,
      exitCode: code, exitStatus: status, failedToStart: failedToStart }
    internal.stdoutText = ""
    internal.stderrText = ""
    internal.active = false
    completed(result)
  }

  property Process process: Process {
    onStarted: {
      internal.didStart = true
      write(internal.input)
      internal.input = ""
      stdinEnabled = false
      runner.started()
    }
    stdout: StdioCollector {
      onStreamFinished: internal.stdoutText = text
    }
    stderr: StdioCollector {
      onStreamFinished: internal.stderrText = text
    }
    // Installed Process flushes both collectors before exited. FailedToStart only
    // emits runningChanged, without started, exited, or streamFinished.
    onExited: (code, status) => runner.finish(code, status, false)
    onRunningChanged: {
      if (runner.busy && !running && !internal.didStart) {
        stdinEnabled = false
        runner.finish(-1, -1, true)
      }
    }
  }
}
