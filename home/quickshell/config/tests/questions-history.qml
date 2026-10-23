import QtQuick
import Quickshell
import "../features/questions" as Questions

ShellRoot {
  FakeRunner { id: fixtureRunner }
  Questions.History { id: history; runner: fixtureRunner; sessionsDirectory: "/isolated/history" }
  TestHarness {
    id: t
    steps: [
      () => {
        t.equal(history.results.length, 0, "initial history is empty")
        t.verify(history.refresh(), "refresh starts")
        t.verify(history.busy && !history.refresh(), "overlapping refresh rejected")
        t.equal(fixtureRunner.calls[0].argv[2], "/isolated/history", "session directory passed as a single argument")
        fixtureRunner.finish(JSON.stringify([
          {id: "new", timestamp: "2026-10-23T00:00:00Z", question: "Qt Markdown", answer: "Official documentation"},
          {id: "old", timestamp: "2026-10-22T00:00:00Z", question: "Documentation", answer: "Different answer"}
        ]))
        t.verify(!history.busy && history.error === "", "successful load settles")
        history.query = "  qT\nOFFICIAL  "
        t.equal(history.results.length, 1, "case-insensitive AND terms match across question and answer")
        t.equal(history.results[0].id, "new", "correct entry selected")
        history.query = "Qt missing"
        t.equal(history.results.length, 0, "every query term is required")
        history.query = " documentation "
        t.equal(history.results.length, 2, "answer and question are searchable")
        t.equal(history.results[0].id, "new", "search retains newest-first order")
        history.query = " \n "
        t.equal(history.results.length, 2, "whitespace-only query shows all entries")
        history.refresh()
        fixtureRunner.finish("[]")
        t.equal(history.entries.length, 0, "refresh replaces old results with empty state")
        history.refresh()
        fixtureRunner.finish("", "private details", 1)
        t.verify(history.error.length > 0 && !history.busy, "load failure is visible")
        t.verify(history.error.indexOf("private details") === -1, "raw errors are not shown")
        history.refresh()
        fixtureRunner.finish("malformed")
        t.verify(history.error.length > 0, "invalid loader response is visible")
        history.refresh()
        fixtureRunner.finish("[]")
        t.equal(history.error, "", "subsequent refresh recovers")
        fixtureRunner.busy = true
        t.verify(!history.refresh() && !history.busy && history.error.length > 0, "runner rejection settles without hanging")
        fixtureRunner.busy = false
      }
    ]
  }
}
