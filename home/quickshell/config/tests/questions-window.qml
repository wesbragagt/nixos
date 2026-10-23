import QtQuick
import Quickshell
import "../layouts" as Layouts
import "../features/questions" as Questions
ShellRoot {
  FakeAcpTransport { id: wire }
  Questions.State { id: state; transport: wire }
  QtObject { id: screens; property var screens: Quickshell.screens }
  QtObject { id: monitor; property var focusedMonitor: ({name: "missing"}) }
  Layouts.Questions { id: panel; featureState: state; screenSource: screens; monitorSource: monitor; ipcEnabled: false }
  TestHarness {
    id: t
    steps: [
      () => {
        t.verify(!panel.visible, "window initially hidden")
        panel.toggle()
        t.verify(panel.visible && panel.selectedScreen === Quickshell.screens[0], "unknown focused monitor falls back to first screen")
        state.submit("preserved question")
        screens.screens = []
      },
      () => {
        t.verify(!panel.visible, "screen removal hides panel")
        t.verify(state.busy, "screen removal preserves in-flight State")
        panel.toggle()
        t.verify(!panel.visible, "no screens cannot open window")
        wire.finish()
        screens.screens = Quickshell.screens
        panel.toggle()
        t.verify(panel.visible, "available screen can reopen window")
        panel.toggle()
        t.verify(!panel.visible, "toggle closes same window")
      }
    ]
  }
}
