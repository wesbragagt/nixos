import QtQuick

Item {
  id: harness
  property var steps: []
  property int step: 0
  property int attempts: 0
  property int checks: 0
  property bool failed: false
  function verify(condition, message) {
    checks++
    if (!condition) {
      failed = true
      console.error("FAIL: " + message)
      Qt.quit()
      throw new Error(message)
    }
  }
  function equal(actual, expected, message) {
    verify(actual === expected, message + ": expected " + expected + ", got " + actual)
  }
  // Each step returns false while awaiting a signal; 5s deadline per step.
  Timer {
    interval: 10
    running: !harness.failed
    repeat: true
    onTriggered: {
      if (harness.step === harness.steps.length) {
        stop()
        console.log("BEHAVIOR PASS: " + harness.checks + " assertions")
        Qt.quit()
        return
      }
      if (++harness.attempts > 500) {
        harness.verify(false, "step " + harness.step + " timed out")
        return
      }
      if (harness.steps[harness.step]() !== false) {
        harness.step++
        harness.attempts = 0
      }
    }
  }
}
