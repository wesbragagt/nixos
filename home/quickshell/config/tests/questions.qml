import QtQuick
import Quickshell
import "../features/questions" as Questions

ShellRoot {
  FakeRunner { id: browser }
  FakeRunner { id: mover }
  QtObject {
    id: compositor
    property var focusedWorkspace: ({id: 4})
    signal rawEvent(var event)
  }
  FakeAcpTransport { id: wire }
  Questions.State { id: state; transport: wire; browser: browser; mover: mover; compositor: compositor }
  function begin(id) {
    wire.started()
    wire.reply({protocolVersion: 1, agentCapabilities: {sessionCapabilities: {close: {}}}})
    wire.reply({sessionId: id})
  }
  function settle(reason) {
    wire.reply({stopReason: reason})
    wire.reply({})
    wire.finish()
  }
  TestHarness {
    id: t
    steps: [
      () => {
        t.verify(!state.submit("  "), "blank questions rejected")
        t.verify(state.submit("first question"), "first question accepted")
        const launch = wire.launches[0].argv
        t.equal(launch[launch.indexOf("--model") + 1], "ccflare/gpt-6-luna", "questions always use the pinned model")
        t.equal(launch[launch.indexOf("--thinking") + 1], "low", "questions use low thinking effort")
        t.verify(!state.submit("overlap"), "overlap rejected")
        begin("first")
        wire.chunk("first", "Looking up", "preamble")
        wire.update("first", {sessionUpdate: "agent_thought_chunk", content: {type: "text", text: "private thought"}})
        wire.chunk("stale", "old answer", "stale")
        wire.chunk("first", "## Answer\n", "final")
        wire.chunk("first", "A cited result.", "final")
        wire.update("first", {sessionUpdate: "tool_call", toolCallId: "search", title: "Web search", status: "in_progress"})
        t.verify(state.toolActivity.indexOf("Web search") >= 0, "active search is visible")
        wire.update("first", {sessionUpdate: "tool_call_update", toolCallId: "search", status: "completed"})
        t.equal(state.toolActivity, "", "sparse completion leaves writing status")
        t.equal(state.answer, "## Answer\nA cited result.", "final assistant message replaces preamble and excludes thought/stale updates")
        wire.frameReceived({jsonrpc: "2.0", id: 90, method: "session/request_permission", params: {sessionId: "first", options: []}})
        const denial = wire.sent[wire.sent.length - 1]
        t.equal(denial.result.outcome.outcome, "cancelled", "permission never escalates")
        // Respond to the outstanding prompt rather than the permission response.
        const prompt = wire.sent.find(frame => frame.method === "session/prompt")
        wire.frameReceived({jsonrpc: "2.0", id: prompt.id, result: {stopReason: "end_turn"}})
        wire.reply({})
        wire.finish()
        t.verify(!state.busy, "settled process returns idle")
        t.verify(state.submit("independent question"), "second independent question accepted")
        begin("second")
        t.equal(state.answer, "", "second question has no prior answer")
        wire.chunk("second", "partial", "m")
        state.cancel()
        t.verify(wire.sent.some(frame => frame.method === "session/cancel"), "Stop requests ACP cancellation")
        const secondPrompt = wire.sent.find(frame => frame.method === "session/prompt")
        wire.frameReceived({jsonrpc: "2.0", id: secondPrompt.id, result: {stopReason: "cancelled"}})
        wire.reply({})
        wire.finish()
        t.equal(state.answer, "partial", "cancel preserves partial text")
        t.verify(!state.busy, "cancel completes teardown")
        t.verify(state.clear(), "completed answer can be cleared")
        t.equal(state.answer, "", "clear removes answer")
        state.submit("startup failure")
        wire.failed("OMP could not start. Check the configured executable.")
        wire.finish(-1, -1)
        t.verify(!state.busy && state.error.length > 0, "startup error is visible and recoverable")
        state.submit("recovery")
        begin("third")
        wire.chunk("third", "limited", "m")
        settle("max_tokens")
        t.equal(state.answer, "limited", "token limit preserves answer")
        t.verify(state.outcome !== "", "token limit marks incomplete outcome")
        for (const reason of ["refusal", "max_turn_requests", "end_turn"]) {
          state.submit(reason)
          begin(reason)
          settle(reason)
          t.equal(state.outcome, reason === "refusal" ? "refused" : "incomplete", "empty/limited result remains explicit: " + reason)
        }
        t.verify(state.openUrl("https://doc.qt.io/"), "https source link launches")
        t.equal(browser.detachedCalls[0].argv.join(" "), "chromium --new-window https://doc.qt.io/", "links open in a new Chromium window")
        t.verify(!state.openUrl("file:///etc/passwd") && browser.detachedCalls.length === 1, "non-HTTP(S) links never launch")
        compositor.rawEvent({name: "openwindow", data: "aaa,4,foot,term"})
        compositor.rawEvent({name: "openwindow", data: "abc,3,chromium-browser,Qt, Docs"})
        t.equal(mover.detachedCalls.length, 1, "only the new Chromium window is moved")
        t.equal(mover.detachedCalls[0].argv.join(" "), "hyprctl dispatch movetoworkspace 4,address:0xabc", "window moves to the clicked workspace")
        compositor.rawEvent({name: "openwindow", data: "def,3,chromium-browser,Other"})
        t.equal(mover.detachedCalls.length, 1, "later windows are left alone")
        compositor.focusedWorkspace = {id: 6}
        state.openUrl("https://example.com/")
        compositor.rawEvent({name: "openwindow", data: "ghi,6,chromium-browser,Example"})
        t.equal(mover.detachedCalls.length, 1, "a window already on the workspace is not moved")
      }
    ]
  }
}
