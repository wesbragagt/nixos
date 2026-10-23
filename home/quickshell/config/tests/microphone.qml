import QtQuick
import Quickshell
import "../features/microphone" as Microphone
ShellRoot {
  FakeRunner { id: status }
  FakeRunner { id: mutation }
  Microphone.State { id: mic; pollingEnabled: false; statusRunner: status; mutationRunner: mutation }
  FloatingWindow {
    id: host
    visible: false
    Microphone.Widget { featureState: mic; popupHostWindow: host }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        t.equal(status.calls.length, 0, "disabled polling does not start capture controller queries")
        mic.refresh()
        status.finish('{"status":"running","enabled":false,"preset":"Balanced","source":"physical"}')
        t.equal(mic.enabled, false, "raw bypass reported independently of service readiness")
        mic.toggle()
        t.verify(!mic.setPreset("Strong"), "busy mutation cannot overlap preset change")
        status.start(["fixture"])
        status.finish('{"status":"failed","enabled":false,"preset":"Light"}')
        t.equal(mic.status, "running", "in-flight mutation ignores stale status result")
        mutation.finish('{"status":"running","enabled":true,"preset":"Strong","source":"physical"}')
        t.equal(mic.enabled, true, "mutation completion publishes suppression enabled")
        t.equal(mic.preset, "Strong", "mutation publishes selected preset")
        t.verify(!mic.setPreset("unknown"), "unknown preset rejected")
        mic.refresh()
        status.finish('invalid')
        t.equal(mic.status, "unavailable", "malformed controller output becomes unavailable")
        mic.restart()
        mutation.finish('{"status":"failed","enabled":true,"preset":"Strong","error":"Model checksum mismatch"}', "", 1)
        t.equal(mic.error, "Model checksum mismatch", "controller error remains visible")
      }
    ]
  }
}
