import QtQuick
import Quickshell
import QtTest
import "../features/questions" as Questions
ShellRoot {
  property int closes: 0
  property string opened: ""
  TestCase { id: keys; name: "QuestionInput"; when: false }
  FakeAcpTransport { id: wire }
  Questions.State { id: state; transport: wire }
  FloatingWindow {
    id: host
    visible: true
    implicitWidth: 820
    implicitHeight: 720
    Questions.Widget {
      id: widget
      anchors.fill: parent
      featureState: state
      openLink: link => opened = link
      onCloseRequested: closes++
    }
  }
  TestHarness {
    id: t
    steps: [
      () => { widget.focusInput(); widget.input.text = "First line" },
      () => {
        keys.keyClick(Qt.Key_Return, Qt.ShiftModifier)
        t.verify(widget.input.text.indexOf("\n") >= 0, "Shift+Enter inserts newline")
        t.equal(wire.launches.length, 0, "Shift+Enter never submits")
        keys.keyClick(Qt.Key_Return)
        t.equal(wire.launches.length, 1, "Enter submits question")
        keys.keyClick(Qt.Key_Escape)
        t.equal(closes, 1, "Escape closes from question input")
        t.verify(state.busy, "closing keeps active question")
        wire.finish()
        state.answer = "[Qt documentation](https://doc.qt.io/)"
      },
      () => {
        if (!widget.answerEdit.text.length) return false
        widget.focusInput()
        keys.keyClick(Qt.Key_Tab)
        t.verify(!widget.input.activeFocus, "Tab traverses from question input")
        const edit = widget.answerEdit
        // Hit-test the native rendered link, then exercise its real pointer path.
        let point = null
        for (let y = 1; y < Math.min(edit.height, 60) && !point; y += 2) {
          for (let x = 1; x < Math.min(edit.width, 240); x += 2) {
            if (edit.linkAt(x, y) && edit.linkAt(x + 8, y + 4)) { point = {x: x + 4, y: y + 2}; break }
          }
        }
        t.verify(point !== null, "Markdown exposes a native clickable source")
        const rect = edit.positionToRectangle(4)
        keys.mouseMove(edit, rect.x + 2, rect.y + rect.height / 2)
        keys.mouseClick(edit, rect.x + 2, rect.y + rect.height / 2, Qt.LeftButton)
      },
      () => {
        t.equal(opened, "https://doc.qt.io/", "native link activation reaches filtered opener")
        widget.focusInput()
        widget.answerEdit.select(0, 2)
        widget.copyAnswer()
        t.verify(widget.input.activeFocus, "Copy answer restores question focus")
        t.equal(widget.answerEdit.selectedText, "Qt", "Copy answer restores selected text")
        widget.input.clear()
        widget.input.paste()
        t.equal(widget.input.text.trim(), "Qt documentation", "clipboard contains rendered answer rather than Markdown")
        widget.answerEdit.forceActiveFocus()
        keys.keyClick(Qt.Key_Escape)
        t.equal(closes, 2, "Escape closes from answer selection")
      }
    ]
  }
}
