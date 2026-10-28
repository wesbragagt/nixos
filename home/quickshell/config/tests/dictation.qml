import QtQuick
import Quickshell
import "../features/dictation" as Dictation
ShellRoot {
  FakeRunner { id: status }
  FakeRunner { id: mutation }
  Dictation.State { id: dictation; featureEnabled: true; pollingEnabled: false; statusRunner: status; mutationRunner: mutation }
  FloatingWindow {
    id: host
    visible: false
    Dictation.Widget { featureState: dictation; popupHostWindow: host }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        t.equal(status.calls.length, 0, "disabled polling runs no dictate command")
        dictation.refresh()
        status.finish('{"state":"idle","language":"auto","depth":"full","insert":"type","mic":"default","mics":[{"name":"alsa_input.usb","description":"USB Mic"}],"keywords":["NixOS"],"history":[{"time":"t","text":"hello"}]}')
        t.verify(dictation.available, "valid status marks dictate available")
        t.equal(dictation.keywords[0], "NixOS", "keywords published")
        t.equal(dictation.mics.length, 1, "microphones published")
        dictation.setOption("language", "de")
        t.equal(mutation.calls[0].argv.join(" "), "dictate set language de", "language change uses set command")
        t.verify(!dictation.setKeywords("x"), "busy mutation cannot overlap keyword save")
        status.start(["fixture"])
        status.finish('{"state":"recording","language":"auto","depth":"full","insert":"type","mic":"default"}')
        t.equal(dictation.recording, false, "in-flight mutation ignores stale status result")
        mutation.finish('{"state":"idle","language":"de","depth":"full","insert":"type","mic":"default"}')
        t.equal(dictation.language, "de", "mutation publishes new language")
        dictation.setKeywords("Krzysztof\n")
        t.equal(mutation.receivedInput, "Krzysztof\n", "keywords sent on stdin")
        t.equal(mutation.calls[1].argv.join(" "), "dictate keywords", "keywords command has no argv payload")
        mutation.finish("", "invalid", 2)
        t.equal(status.calls.length, 3, "failed mutation triggers a status refresh")
        status.finish('invalid')
        t.verify(!dictation.available, "malformed output marks dictate unavailable")
      }
    ]
  }
}
