import QtQuick

QtObject {
  id: runner
  property var environment: ({ LC_ALL: "C.UTF-8" })
  property bool busy: false
  property var calls: []
  property var detachedCalls: []
  // Test-only stdin inspection; never use real credentials in fixtures.
  property string receivedInput: ""
  signal started()
  signal completed(var result)
  signal detachedRequested()
  function start(argv, input, overrides) {
    if (busy || !argv || argv.length === 0) return false
    busy = true
    calls = calls.concat([{ argv: argv.slice(), environment: Object.assign({}, environment, overrides || {}) }])
    receivedInput = input === undefined ? "" : input
    started()
    return true
  }
  function finish(stdout, stderr, exitCode, exitStatus, failedToStart) {
    receivedInput = ""
    busy = false
    completed({ stdout: stdout || "", stderr: stderr || "", exitCode: exitCode === undefined ? 0 : exitCode,
      exitStatus: exitStatus === undefined ? 0 : exitStatus, failedToStart: !!failedToStart })
  }
  function launchDetached(argv, overrides) {
    if (busy || !argv || argv.length === 0) return false
    detachedCalls = detachedCalls.concat([{ argv: argv.slice(), environment: Object.assign({}, environment, overrides || {}) }])
    detachedRequested()
    return true
  }
}
