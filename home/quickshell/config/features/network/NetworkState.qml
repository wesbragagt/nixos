import QtQuick
import "../../shared" as Shared

Item {
  id: root
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property var scanRunner: Shared.CommandRunner {}
  property var connectRunner: Shared.CommandRunner {}
  property var radioRunner: Shared.CommandRunner {}
  property var settingsRunner: Shared.CommandRunner {}
  property string networkType: ""
  property var networks: []
  property bool wifiEnabled: false
  property string connection: "Checking connection…"
  property string errorMessage: ""
  property string connectionMessage: ""
  readonly property bool loading: scanRunner.busy
  readonly property bool connecting: connectRunner.busy
  readonly property bool radioBusy: radioRunner.busy
  readonly property int popupCount: demands.length
  readonly property bool scanningRequested: popupCount > 0
  readonly property bool scanPollingActive: pollingEnabled && scanningRequested
  property var demands: []
  property int nextDemand: 0
  property string connectionTarget: ""
  signal connected(string ssid)

  function refresh() {
    return statusRunner.start(["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"], "", {LC_ALL: "C"})
  }
  function scan() {
    return scanRunner.start(["sh", "-c", "nmcli radio wifi; printf '\\nDEVICES\\n'; nmcli -t --escape no -f TYPE,STATE,CONNECTION device status; printf '\\nNETWORKS\\n'; nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto"], "", {LC_ALL: "C"})
  }
  function openPopup() {
    const token = ++nextDemand
    demands = demands.concat([token])
    scan()
    return token
  }
  function closePopup(token) {
    demands = demands.filter(value => value !== token)
  }
  function refreshNetworks() { errorMessage = ""; return scan() }
  function dismissConnectionMessage() { connectionMessage = "" }
  function clearMessages() { errorMessage = ""; connectionMessage = "" }
  function connectNetwork(network, password) {
    if (!network || connecting) return false
    const target = String(network.ssid)
    errorMessage = ""
    connectionTarget = target
    connectionMessage = "Connecting to " + target + "…"
    return connectRunner.start(["nmcli", "--colors", "no", "--wait", "30", "--ask", "device", "wifi", "connect", target], password + "\n", {LC_ALL: "C"})
  }
  function toggleRadio() {
    if (radioBusy || loading || connecting) return false
    errorMessage = ""
    return radioRunner.start(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"], "", {LC_ALL: "C"})
  }
  function openSettings() {
    return settingsRunner.launchDetached(["foot", "--title=Network settings", "nmtui"])
  }
  function applyScan(text) {
    wifiEnabled = text.split("\n")[0].trim() === "enabled"
    const sections = text.split("\nNETWORKS\n")
    const devices = sections[0].split("\n")
    const wired = devices.find(line => line.startsWith("ethernet:connected:"))
    const wireless = devices.find(line => line.startsWith("wifi:connected:"))
    connection = wired ? "Ethernet · " + wired.substring(19)
      : wireless ? "Wi-Fi · " + wireless.substring(15) : "Not connected"
    const found = new Map()
    for (const line of (sections[1] || "").split("\n")) {
      const fields = line.split(":")
      if (fields.length < 4) continue
      const ssid = fields.slice(3).join(":")
      if (!ssid) continue
      const entry = {ssid: ssid, signal: Number(fields[1]), security: fields[2], active: fields[0] === "*"}
      const old = found.get(ssid)
      if (!old || entry.active || (!old.active && entry.signal > old.signal)) found.set(ssid, entry)
    }
    networks = Array.from(found.values()).sort((a, b) => Number(b.active) - Number(a.active) || b.signal - a.signal)
  }
  Connections {
    target: root.statusRunner
    function onCompleted(result) {
      root.networkType = /^ethernet:connected$/m.test(result.stdout) ? "ethernet"
        : /^wifi:connected$/m.test(result.stdout) ? "wifi" : ""
    }
  }
  Connections {
    target: root.scanRunner
    function onCompleted(result) {
      root.applyScan(result.stdout)
      if (result.stderr.trim()) root.errorMessage = result.stderr.trim()
    }
  }
  Connections {
    target: root.connectRunner
    function onCompleted(result) {
      const target = root.connectionTarget
      root.connectionTarget = ""
      if (result.stderr.trim()) root.errorMessage = result.stderr.trim()
      root.connectionMessage = result.exitCode === 0 ? "Connected to " + target : "Connection failed. Check your password and try again."
      if (result.exitCode === 0) root.connected(target)
      root.scan()
    }
  }
  Connections {
    target: root.radioRunner
    function onCompleted(result) {
      if (result.stderr.trim()) root.errorMessage = result.stderr.trim()
      root.scan()
    }
  }
  Timer { interval: 2000; repeat: true; running: root.pollingEnabled; onTriggered: root.refresh() }
  Timer { interval: 10000; repeat: true; running: root.scanPollingActive; onTriggered: root.scan() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
