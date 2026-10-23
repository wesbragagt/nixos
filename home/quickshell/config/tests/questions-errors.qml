import QtQuick
import Quickshell
import "../features/questions" as Questions

ShellRoot {
  FakeAcpTransport { id: wire }
  Questions.State {
    id: state
    transport: wire
    initializeTimeoutMs: 40
    createTimeoutMs: 40
    cancelTimeoutMs: 40
    closeTimeoutMs: 40
    terminateTimeoutMs: 40
  }
  TestHarness {
    id: t
    steps: [
      () => { state.submit("deadline"); wire.started() },
      () => {
        if (!state.error) return false
        t.verify(state.busy, "deadline still owns process until exit")
        wire.finish()
        t.verify(!state.busy, "deadline exit releases busy")
        state.submit("protocol")
        wire.started()
        wire.reply({protocolVersion: 9})
        t.verify(state.error.length > 0, "unsupported protocol is actionable")
        wire.finish()
        state.submit("provider")
        wire.started()
        wire.reply({protocolVersion: 1, agentCapabilities: {}})
        wire.reply({sessionId: "err"})
        wire.chunk("err", "partial", "m")
        const prompt = wire.sent[wire.sent.length - 1]
        wire.frameReceived({jsonrpc: "2.0", id: prompt.id, error: {code: -32000, message: "Provider unavailable"}})
        t.equal(state.answer, "partial", "provider failure preserves partial answer")
        t.verify(state.error.indexOf("Provider unavailable") >= 0, "provider failure remains concrete")
        wire.finish()
        state.submit("malformed")
        wire.started()
        wire.failed("Malformed ACP JSON")
        t.verify(state.error.indexOf("Malformed") >= 0, "malformed transport error visible")
        wire.finish()
        state.submit("early cancellation")
        state.cancel()
        t.verify(!wire.sent.some(frame => frame.method === "session/cancel"), "cancel before session sends no invalid notification")
        wire.finish()
        t.verify(!state.busy, "early cancellation returns idle")
      }
    ]
  }
}
