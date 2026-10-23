import QtQuick
import Quickshell
import "../features/questions" as Questions

ShellRoot {
  property var frames: []
  property bool done: false
  Questions.AcpTransport {
    id: wire
    onStarted: send({hello: "duplex"})
    onFrameReceived: frame => frames = frames.concat([frame])
    onExited: done = true
  }
  TestHarness {
    id: t
    steps: [
      () => {
        wire.start(["python3", "-u", "-c", "import sys,time,json; line=sys.stdin.readline(); print('diagnostic',file=sys.stderr,flush=True); sys.stdout.write('{\"first\":'); sys.stdout.flush(); time.sleep(.05); sys.stdout.write('1}\\n{\"second\":2}\\n'); sys.stdout.flush()"], "/tmp")
      },
      () => {
        if (!done) return false
        t.equal(frames.length, 2, "split and coalesced lines emit two frames")
        t.equal(frames[0].first, 1, "split frame preserved")
        t.equal(frames[1].second, 2, "coalesced frame preserved")
        t.verify(wire.diagnostics.indexOf("diagnostic") >= 0, "stderr retained separately")
      }
    ]
  }
}
