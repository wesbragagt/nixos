import QtQuick

QtObject {
  id: fake
  property bool busy: false
  property string diagnostics: ""
  property var sent: []
  property var launches: []
  property int closes: 0
  property int terminations: 0
  signal started()
  signal frameReceived(var frame)
  signal failed(string message)
  signal exited(int code, int status)
  function start(argv, cwd) {
    if (busy) return false
    busy = true
    sent = []
    diagnostics = ""
    launches = launches.concat([{argv: argv, cwd: cwd}])
    return true
  }
  function send(frame) {
    if (!busy) return false
    sent = sent.concat([frame])
    return true
  }
  function close() { closes++ }
  function terminate() { terminations++ }
  function forceStop() { finish(9, 1) }
  function finish(code, status) {
    busy = false
    exited(code === undefined ? 0 : code, status === undefined ? 0 : status)
  }
  function reply(result) {
    const request = sent[sent.length - 1]
    frameReceived({jsonrpc: "2.0", id: request.id, result: result})
  }
  function update(session, update) {
    frameReceived({jsonrpc: "2.0", method: "session/update", params: {sessionId: session, update: update}})
  }
  function chunk(session, text, id) {
    update(session, {sessionUpdate: "agent_message_chunk", content: {type: "text", text: text}, messageId: id})
  }
}
