import QtQuick
import Quickshell
import "../shared" as Shared

ShellRoot {
  Shared.CommandRunner { id: first }
  Shared.CommandRunner { id: second }
  property var results: []
  property var otherResults: []
  property int starts: 0
  property int launches: 0
  Connections {
    target: first
    function onStarted() { starts++ }
    function onCompleted(result) { results = results.concat([result]) }
    function onDetachedRequested() { launches++ }
  }
  Connections {
    target: second
    function onCompleted(result) { otherResults = otherResults.concat([result]) }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        t.verify(!first.start([]), "empty command rejected")
        t.verify(first.start(["sh", "-c", "read -r line; printf '%s|%s' \"$line\" \"$FOUNDATION_TEST\"; printf 'problem' >&2; sleep 0.1; printf '|tail'; exit 7"], "fixture input\n", { FOUNDATION_TEST: "env" }), "accept real command")
        t.verify(first.busy, "busy immediately, before started")
        t.verify(!first.start(["sh", "-c", "exit 0"]), "busy start rejected")
        t.verify(!first.launchDetached(["true"]), "busy detached request rejected")
        t.verify(second.start(["sh", "-c", "printf independent"]), "independent runner accepted")
      },
      () => {
        if (!otherResults.length) return false
        t.equal(otherResults[0].stdout, "independent", "independent output")
        t.verify(first.busy, "independent child completes while first still runs")
        return true
      },
      () => {
        if (!results.length) return false
        const r = results[0]
        t.equal(r.stdout, "fixture input|env|tail", "stdin, environment, and late stdout complete")
        t.equal(r.stderr, "problem", "stderr complete before result")
        t.equal(r.exitCode, 7, "nonzero exit retained")
        t.equal(r.exitStatus, 0, "normal exit status retained")
        t.equal(r.failedToStart, false, "nonzero exit is not startup failure")
        t.equal(starts, 1, "busy request did not restart child")
        t.verify(!first.busy, "idle at completion")
        t.equal(first.internal.input, "", "stdin cleared after delivery")
        t.verify(first.start(["/definitely-missing-quickshell-foundation-command"], "unused fixture"), "startup attempt accepted")
      },
      () => {
        if (results.length < 2) return false
        const r = results[1]
        t.verify(r.failedToStart, "missing executable publishes startup failure")
        t.equal(r.exitCode, -1, "startup failure has no exit code")
        t.equal(r.exitStatus, -1, "startup failure has no exit status")
        t.equal(r.stdout, "", "no previous stdout on failure")
        t.equal(r.stderr, "", "no previous stderr on failure")
        t.equal(first.internal.input, "", "failed startup clears transient stdin")
        t.verify(first.start(["sh", "-c", "test \"$LC_ALL\" = C.UTF-8 && printf recovered"]), "runner reusable after failure")
      },
      () => {
        if (results.length < 3) return false
        t.equal(results[2].stdout, "recovered", "English locale and reuse")
        t.equal(results[2].exitCode, 0, "recovery exit")
        t.verify(first.launchDetached(["true"]), "harmless detached request submitted")
        t.equal(launches, 1, "detached submission observed")
        t.verify(!first.busy, "detached has no tracked lifetime")
        t.equal(results.length, 3, "detached has no fabricated exit result")
      }
    ]
  }
}
