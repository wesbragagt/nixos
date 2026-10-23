import QtQuick
import Quickshell.Io

QtObject {
  id: transport

  readonly property bool busy: internal.active
  readonly property string diagnostics: internal.stderrText

  signal started()
  signal frameReceived(var frame)
  signal failed(string message)
  signal exited(int code, int status)

  function start(argv, cwd): bool {
    if (busy || process.running || !Array.isArray(argv) || argv.length === 0)
      return false
    if (typeof cwd !== "string" || !cwd.startsWith("/")) return false
    for (let i = 0; i < argv.length; ++i) {
      if (typeof argv[i] !== "string" || (i === 0 && argv[i].length === 0))
        return false
    }

    internal.didStart = false
    internal.didFail = false
    internal.stopSignal = 0
    internal.stderrText = ""
    internal.active = true
    process.environment = { LC_ALL: "C.UTF-8" }
    process.workingDirectory = cwd
    process.command = argv.slice()
    // close() is per child: a later start must explicitly reopen stdin.
    process.stdinEnabled = true
    process.running = true
    return true
  }

  function send(frame): bool {
    if (!busy || !internal.didStart || internal.didFail || !process.running
        || !process.stdinEnabled || frame === null || typeof frame !== "object"
        || Array.isArray(frame)) return false
    let encoded
    try {
      encoded = JSON.stringify(frame)
    } catch (_) {
      return false
    }
    if (typeof encoded !== "string" || !encoded.startsWith("{")) return false
    process.write(encoded + "\n")
    return true
  }

  function close(): void {
    process.stdinEnabled = false
  }

  function terminate(): void {
    stopChild(15)
  }

  function forceStop(): void {
    stopChild(9)
  }

  function stopChild(signalNumber): void {
    if (!busy) return
    // Process.signal() calls kill(pid, signal). Never let a not-yet-started
    // child's pid of zero turn cancellation into a process-group signal.
    if (signalNumber === 9 || internal.stopSignal === 0)
      internal.stopSignal = signalNumber
    if (internal.didStart && Number(process.processId) > 0)
      process.signal(internal.stopSignal)
  }

  function fail(message): void {
    if (!busy || internal.didFail) return
    internal.didFail = true
    failed(message)
  }

  function receiveLine(line): void {
    if (!busy || internal.didFail || line.trim().length === 0) return
    let frame
    try {
      frame = JSON.parse(line)
    } catch (_) {
      fail("OMP sent malformed JSON on its ACP output.")
      return
    }
    if (frame === null || typeof frame !== "object" || Array.isArray(frame)) {
      fail("OMP sent a non-object ACP frame.")
      return
    }
    frameReceived(frame)
  }

  function appendDiagnostics(data): void {
    if (!busy) return
    // An empty-marker SplitParser delivers stderr chunks immediately, including
    // unterminated lines, without retaining an unbounded collector buffer.
    const tail = (internal.stderrText + data.slice(-8192)).slice(-8192)
    let bytes = 0
    let first = tail.length
    while (first > 0) {
      let index = first - 1
      const code = tail.charCodeAt(index)
      let size = code < 0x80 ? 1 : code < 0x800 ? 2 : 3
      if (code >= 0xdc00 && code <= 0xdfff && index > 0) {
        const previous = tail.charCodeAt(index - 1)
        if (previous >= 0xd800 && previous <= 0xdbff) {
          --index
          size = 4
        }
      }
      if (bytes + size > 8192) break
      bytes += size
      first = index
    }
    internal.stderrText = tail.slice(first)
  }

  function finish(code, status): void {
    if (!busy) return
    close()
    internal.active = false
    internal.stopSignal = 0
    exited(code, status)
  }

  property QtObject internal: QtObject {
    property bool active: false
    property bool didStart: false
    property bool didFail: false
    property int stopSignal: 0
    property string stderrText: ""
  }

  property Process process: Process {
    onStarted: {
      if (!transport.busy || internal.didStart) return
      internal.didStart = true
      transport.started()
      if (transport.busy && internal.stopSignal !== 0 && Number(processId) > 0)
        signal(internal.stopSignal)
    }
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => transport.receiveLine(data)
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: data => transport.appendDiagnostics(data)
    }
    // Quickshell flushes parsers before exited. FailedToStart emits only
    // runningChanged, so synthesize an exit to settle teardown in that case.
    onExited: (code, status) => transport.finish(code, status)
    onRunningChanged: {
      if (transport.busy && !running && !internal.didStart) {
        transport.fail("OMP could not start. Check the configured executable.")
        transport.finish(-1, -1)
      }
    }
  }

  Component.onDestruction: {
    close()
    terminate()
  }
}
