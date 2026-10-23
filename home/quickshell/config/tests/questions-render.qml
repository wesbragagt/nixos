import QtQuick
import Quickshell
import "../features/questions" as Questions
ShellRoot {
  property bool captured: false
  property string opened: ""
  QtObject {
    id: state
    property string question: ""
    property string submittedQuestion: "Markdown rendering fixture"
    property string answer: ""
    property string error: ""
    property string outcome: ""
    property string phase: "answering"
    property string toolActivity: "Search · completed"
    property bool busy: true
    function submit(text) { return false }
    function clear() { answer = ""; return true }
    function cancel() { busy = false }
  }
  FloatingWindow {
    visible: true
    implicitWidth: 820
    implicitHeight: 720
    color: "transparent"
    Questions.Widget { id: widget; anchors.fill: parent; featureState: state; openLink: link => opened = link }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        state.answer = "# A readable answer\n\n**Markdown**, with a source [Qt TextEdit](https://doc.qt.io/qt-6/qml-qtquick-textedit.html).\n\n- First point\n- Second point\n\n```qml\nTextEdit { textFormat: TextEdit.MarkdownText }\n```\n\n| Setting | Value |\n|---|---|\n| Protocol | ACP |\n\n" + "A long reading paragraph with content to exercise scrolling. ".repeat(100) + "\n\n" + "LongToken".repeat(60)
      },
      () => {
        if (widget.answerEdit.text.length < 100) return false
        widget.answerEdit.selectAll()
        t.verify(widget.answerEdit.selectedText.indexOf("A readable answer") >= 0, "heading rendered as selectable text")
        t.verify(widget.answerEdit.selectedText.indexOf("**Markdown**") < 0, "emphasis delimiters not rendered")
        t.verify(widget.answerScroll.contentHeight > widget.answerScroll.height, "long response scrolls")
        widget.answerEdit.deselect()
        widget.answerScroll.contentY = 40
        state.answer += "\n\nNew streamed paragraph."
      },
      () => {
        if (widget.answerEdit.text.indexOf("New streamed") < 0) return false
        t.equal(widget.answerScroll.contentY, 40, "streaming preserves reader scroll position")
        widget.answerScroll.contentY = widget.answerScroll.contentHeight - widget.answerScroll.height
        t.verify(widget.answerScroll.atYEnd, "bottom of long answer reachable")
        widget.answerEdit.select(2, 12)
        const selected = widget.answerEdit.selectedText
        t.verify(widget.copyAnswer(), "completed/partial answer can be copied")
        t.equal(widget.answerEdit.selectedText, selected, "copy restores previous selection")
        t.verify(!widget.activateLink("file:///etc/passwd"), "local source link refused")
        t.verify(!widget.activateLink("command:run"), "command link refused")
        t.verify(widget.activateLink("https://doc.qt.io/"), "HTTPS source link accepted")
        t.equal(opened, "https://doc.qt.io/", "accepted source routed to opener")
        widget.grabToImage(result => { result.saveToFile("/tmp/quickshell-questions-render.png"); captured = true })
      },
      () => { if (!captured) return false }
    ]
  }
}
