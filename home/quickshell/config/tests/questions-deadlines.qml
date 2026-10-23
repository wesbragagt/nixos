import QtQuick
import Quickshell
import "../features/questions" as Questions
ShellRoot {
  property int oldRequest: 0
  FakeAcpTransport { id: wire }
  Questions.State {
    id: state
    transport: wire
    initializeTimeoutMs: 50
    createTimeoutMs: 50
    cancelTimeoutMs: 50
    closeTimeoutMs: 50
    terminateTimeoutMs: 50
    turnTimeoutMs: 2000
  }
  function initialize() {
    wire.started()
    wire.reply({protocolVersion: 1, agentCapabilities: {sessionCapabilities: {close: {}}}})
  }
  TestHarness {
    id: t
    steps: [
      () => { state.submit("create timeout"); initialize() },
      () => {
        if (!state.error) return false
        t.verify(state.error.indexOf("creation timed out") >= 0, "session creation deadline is explicit")
        wire.finish()
        state.submit("cancel grace")
        initialize()
        wire.reply({sessionId: "cancel"})
        oldRequest = wire.sent[wire.sent.length - 1].id
        wire.chunk("cancel", "partial", "m")
        state.cancel()
      },
      () => {
        if (!wire.terminations) return false
        t.verify(state.busy, "TERM retains owned child until exit")
        t.verify(!wire.sent.some(frame => frame.method === "session/close"), "unsettled prompt never receives session close")
        wire.frameReceived({jsonrpc: "2.0", id: oldRequest, result: {stopReason: "end_turn"}})
        t.equal(state.outcome, "cancelled", "late completion cannot undo Stop")
      },
      () => {
        if (state.busy) return false
        t.equal(state.answer, "partial", "forced teardown retains partial answer")
        state.submit("close grace")
        initialize()
        wire.reply({sessionId: "close"})
        wire.chunk("close", "done", "m")
        wire.reply({stopReason: "end_turn"})
        t.equal(wire.sent[wire.sent.length - 1].method, "session/close", "settled turn closes session before EOF")
      },
      () => {
        if (state.busy) return false
        t.verify(wire.closes >= 2 && wire.terminations >= 2, "close timeout reaches EOF and TERM then forced exit")
        state.turnTimeoutMs = 50
        state.submit("overall timeout")
        initialize()
        wire.reply({sessionId: "overall"})
      },
      () => {
        if (!state.error) return false
        t.verify(state.error.indexOf("overall deadline") >= 0, "overall deadline bounds active turn")
        wire.finish()
        state.turnTimeoutMs = 2000
        state.submit("late initialization")
        wire.started()
        oldRequest = wire.sent[wire.sent.length - 1].id
        state.cancel()
        wire.frameReceived({jsonrpc: "2.0", id: oldRequest, result: {protocolVersion: 1}})
        t.verify(!wire.sent.some(frame => frame.method === "session/new"), "late initialization after Stop creates no session")
        wire.finish()
      }
    ]
  }
}
