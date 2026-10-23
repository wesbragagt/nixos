import QtQuick
import Quickshell
import "../features/questions" as Questions
ShellRoot {
  property int failures: 0
  property int exits: 0
  Questions.AcpTransport {
    id: wire
    onFailed: failures++
    onExited: exits++
  }
  TestHarness {
    id: t
    steps: [
      () => { wire.start(["/does-not-exist/omp"], "/tmp") },
      () => {
        if (exits !== 1) return false
        t.equal(failures, 1, "failed startup emits actionable failure")
        t.verify(!wire.busy, "nonexistent child does not leave busy transport")
        wire.start(["python3", "-u", "-c", "print('[]',flush=True)"], "/tmp")
      },
      () => {
        if (exits !== 2) return false
        t.equal(failures, 2, "non-object protocol frame rejected after recovery")
        wire.start(["python3", "-u", "-c", "print('not-json',flush=True)"], "/tmp")
      },
      () => {
        if (exits !== 3) return false
        t.equal(failures, 3, "malformed JSON rejected")
        wire.start(["python3", "-u", "-c", "import sys; sys.stderr.write('x'*16000); print('{}',flush=True)"], "/tmp")
      },
      () => {
        if (exits !== 4) return false
        t.equal(wire.diagnostics.length, 8192, "diagnostics retain bounded tail")
        t.verify(!wire.busy, "all real fixture children exited")
      }
    ]
  }
}
