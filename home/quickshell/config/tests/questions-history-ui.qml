import QtQuick
import Quickshell
import "../features/questions" as Questions

ShellRoot {
  property string opened: ""
  property bool captured: false
  QtObject {
    id: state
    property string question: "Current draft"
    property string submittedQuestion: "Current question"
    property string answer: "Current streamed answer"
    property string error: ""
    property string outcome: ""
    property string phase: "answering"
    property string toolActivity: "Live search"
    property bool busy: true
    function submit(text) { return false }
    function clear() {
      if (busy) return false
      question = ""
      answer = ""
      return true
    }
    function cancel() {}
  }
  QtObject {
    id: saved
    property string query: ""
    property bool busy: false
    property string error: ""
    property int refreshes: 0
    property var entries: [
      { id: "new", timestamp: "2026-10-23T12:00:00Z", question: "Qt <b>plain question</b>", answer: "# Saved Qt answer\n\n**Selectable** [source](https://doc.qt.io/)." },
      { id: "old", timestamp: "2026-10-22T12:00:00Z", question: "Older question", answer: "Older answer" }
    ]
    readonly property var results: entries.filter(entry => {
      const haystack = (entry.question + " " + entry.answer).toLowerCase()
      return query.toLowerCase().trim().split(/\s+/).every(term => haystack.indexOf(term) >= 0)
    })
    function refresh() { ++refreshes; return true }
  }
  FloatingWindow {
    visible: true
    implicitWidth: 820
    implicitHeight: 720
    color: "transparent"
    Questions.Widget {
      id: widget
      anchors.fill: parent
      featureState: state
      history: saved
      openLink: link => opened = link
    }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        widget.toggleHistory()
        t.equal(saved.refreshes, 1, "opening history refreshes")
        t.equal(state.question, "Current draft", "opening preserves draft")
        widget.historySearch.text = "qt selectable"
      },
      () => {
        t.equal(saved.results.length, 1, "search matches all terms across question and answer")
        t.verify(widget.chooseHistoryResult(), "Enter action selects first search result")
        state.answer += " while history is open"
        state.error = "Live failure not shown in history"
        state.phase = "closing"
      },
      () => {
        t.equal(widget.renderedAnswer, saved.entries[0].answer, "live chunks and phase changes do not replace saved answer")
        widget.answerEdit.selectAll()
        t.verify(widget.answerEdit.selectedText.indexOf("Saved Qt answer") >= 0, "saved Markdown selectable")
        t.verify(widget.answerEdit.selectedText.indexOf("**Selectable**") < 0, "saved Markdown rendered")
        const selection = widget.answerEdit.selectedText
        t.verify(widget.copyAnswer(), "saved answer copies")
        t.equal(widget.answerEdit.selectedText, selection, "copy restores selection")
        t.verify(widget.activateLink("https://doc.qt.io/"), "saved HTTPS source accepted")
        t.equal(opened, "https://doc.qt.io/", "saved source uses injected opener")
        t.verify(!widget.activateLink("file:///etc/passwd"), "saved local source rejected")
        t.verify(!widget.newQuestion(), "busy clear rejected")
        t.verify(widget.historyVisible, "rejected clear stays in history")
        widget.grabToImage(image => { image.saveToFile("/tmp/quickshell-questions-history-ui.png"); captured = true })
      },
      () => {
        if (!captured) return false
        widget.toggleHistory()
        t.equal(widget.renderedAnswer, state.answer, "return restores latest live answer")
        t.equal(state.question, "Current draft", "return preserves current draft")
        widget.toggleHistory()
        t.equal(saved.refreshes, 2, "reopening refreshes again")
        widget.historySearch.text = ""
      },
      () => {
        widget.historyList.currentIndex = 0
        widget.moveHistorySelection(1)
        widget.chooseHistoryResult()
        t.equal(widget.selectedHistory.id, "old", "Down and Enter choose older row")
        widget.moveHistorySelection(-1)
        widget.chooseHistoryResult()
        t.equal(widget.selectedHistory.id, "new", "Up and Enter choose newer row")
        state.busy = false
        t.verify(widget.newQuestion(), "completed clear accepted")
        t.verify(!widget.historyVisible, "accepted new question returns current mode")
        t.equal(state.question, "", "accepted new question clears current draft")
      }
    ]
  }
}
