import QtQuick
import Quickshell
import "../features/network" as Network
import "../shared" as Shared

ShellRoot {
  readonly property alias domainState: state
  id: suite
  property var second: null
  property color originalBlock: Shared.Theme.block
  property var target: ({ssid: "Lab:Guest", security: "WPA2", active: false, signal: 70})
  FakeRunner { id: status }
  FakeRunner { id: scan }
  FakeRunner { id: connector }
  FakeRunner { id: radio }
  FakeRunner { id: settings }
  Network.NetworkState {
    id: state
    pollingEnabled: false
    statusRunner: status; scanRunner: scan; connectRunner: connector; radioRunner: radio; settingsRunner: settings
  }
  FloatingWindow {
    id: host
    visible: true
    implicitWidth: 800; implicitHeight: 32
    Row {
      Network.NetworkWidget { id: first; networkState: suite.domainState; popupHostWindow: host }
    }
  }
  Component {
    id: widgetFactory
    Network.NetworkWidget { networkState: suite.domainState; popupHostWindow: host }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        t.equal(status.calls.length, 0, "disabled polling has no initial status")
        t.equal(scan.calls.length, 0, "disabled polling has no initial scan")
        t.equal(first.icon, "\uf071", "disconnected warning badge")
        t.verify(state.refresh(), "explicit status starts")
        t.verify(!state.refresh(), "overlapping status skipped")
        status.finish("wifi:connected\nethernet:connected\n")
        t.equal(state.networkType, "ethernet", "wired badge preferred")
        status.start(["fixture"]); status.finish("wifi:disconnected\n")
        t.equal(state.networkType, "", "no connected device")
        second = widgetFactory.createObject(host.contentItem)
        first.panel.visible = true
        second.panel.visible = true
      },
      () => {
        t.equal(state.popupCount, 2, "two popup demands")
        t.equal(scan.calls.length, 1, "opening during scan does not overlap")
        t.verify(!state.scan(), "duplicate scan skipped")
        t.verify(!state.scanPollingActive, "disabled automatic scan timer")
        t.equal(first.panel.emptyMessage, "Wi-Fi is off", "initial off message")
        scan.finish("enabled\nDEVICES\nethernet:connected:Wired:Office\nwifi:connected:Lab:Guest\nNETWORKS\n:95:WPA2:Lab:Guest\n*:40:WPA2:Lab:Guest\n:80:--:Open\n:20:--:Open\n:99:WPA2:\nbad\n")
        t.equal(state.connection, "Ethernet · Wired:Office", "wired connection preferred and colons retained")
        t.equal(state.networks.length, 2, "dedup and hidden SSID omitted")
        t.equal(state.networks[0].ssid, "Lab:Guest", "active first with SSID colon")
        t.equal(state.networks[0].signal, 40, "active duplicate preferred over stronger")
        t.equal(state.networks[1].signal, 80, "strongest inactive duplicate")
        first.panel.selectNetwork(target)
        first.panel.password = "synthetic-network-secret"
        first.panel.revealPassword = true
        second.panel.selectNetwork({ssid: "Other", security: "--", active: false})
        second.panel.password = "independent"
        t.equal(first.panel.selectedNetwork.ssid, "Lab:Guest", "selection stays local")
        t.verify(!second.panel.revealPassword, "reveal stays local")
        t.equal(first.panel.password, "synthetic-network-secret", "password remains local")
        t.verify(first.panel.connectSelected(), "connect accepted")
        t.equal(first.panel.password, "", "send clears local input")
        t.verify(!first.panel.revealPassword, "send clears reveal")
        t.equal(second.panel.password, "independent", "sending leaves other local input alone")
        t.equal(connector.receivedInput, "synthetic-network-secret\n", "credential delivered through stdin")
        t.verify(!JSON.stringify(connector.calls).includes("synthetic-network-secret"), "credential excluded from arguments/environment")
        t.verify(!state.connectNetwork({ssid: "Competing"}, "other-secret"), "competing connection rejected")
        t.equal(connector.calls.length, 1, "one shared connection attempt")
        t.equal(state.connectionTarget, "Lab:Guest", "immutable target captured")
        target.ssid = "Changed local object"
        first.panel.visible = false
      },
      () => {
        t.equal(state.popupCount, 1, "closing one keeps other demand")
        t.equal(first.panel.password, "", "close clears password")
        t.verify(!first.focusRequired, "closed popup releases layout focus requirement")
        t.verify(second.focusRequired, "remaining popup still requests focus")
        connector.finish("", "", 0)
        t.equal(state.connectionMessage, "Connected to Lab:Guest", "completion after close uses captured identity")
        t.equal(connector.receivedInput, "", "test connector drops stdin at completion")
        t.equal(state.connectionTarget, "", "completed target released")
        t.equal(second.panel.selectedNetwork.ssid, "Other", "unrelated local selection survives success")
        scan.finish("enabled\nDEVICES\nwifi:connected:Lab:Guest\nNETWORKS\n")
        t.equal(state.connection, "Wi-Fi · Lab:Guest", "wireless connection colon retained")
        t.equal(second.panel.emptyMessage, "No visible Wi-Fi networks", "empty network message")
        state.pollingEnabled = true
        t.verify(state.scanPollingActive, "remaining demand starts periodic scans")
        second.panel.visible = false
      },
      () => {
        t.equal(state.popupCount, 0, "last close drops final demand")
        t.verify(!state.scanPollingActive, "last close stops periodic scan")
        t.equal(second.panel.password, "", "close clears other credentials")
        second.panel.visible = true
      },
      () => {
        t.equal(state.popupCount, 1, "reopened popup registers once")
        t.verify(state.scanPollingActive, "reopen resumes scan timer")
        second.destroy()
        second = null
      },
      () => {
        t.equal(state.popupCount, 0, "destroying open widget releases demand")
        t.verify(!state.scanPollingActive, "last destruction stops scan timer")
        state.pollingEnabled = false
        scan.finish("enabled\nDEVICES\nNETWORKS\n", " scan unavailable \n", 1)
        t.equal(state.errorMessage, "scan unavailable", "stderr preserved")
        t.equal(state.connection, "Not connected", "empty device list")
        state.refreshNetworks()
        t.equal(state.errorMessage, "", "manual refresh clears error")
        t.equal(first.panel.emptyMessage, "Scanning…", "scan in progress with no results")
        scan.finish("disabled\nDEVICES\nNETWORKS\n")
        t.equal(first.panel.emptyMessage, "Wi-Fi is off", "radio-off message")
        t.verify(state.toggleRadio(), "radio action accepted")
        t.equal(radio.calls[0].argv.join(" "), "nmcli radio wifi on", "off radio toggles on")
        t.verify(!state.toggleRadio(), "busy radio action skipped")
        radio.finish("", "permission denied", 1)
        t.equal(state.errorMessage, "permission denied", "radio failure stderr")
        scan.finish("enabled\nDEVICES\nNETWORKS\n")
        t.verify(state.openSettings(), "settings launch submitted")
        t.equal(settings.detachedCalls[0].argv.join(" "), "foot --title=Network settings nmtui", "settings terminal command")
        first.panel.selectNetwork({ssid: "Failure", security: "WPA2", active: false})
        first.panel.password = "synthetic-failure"
        first.panel.connectSelected()
        first.panel.cancelSelection()
        t.equal(first.panel.password, "", "cancel clears input")
        t.equal(first.panel.selectedNetwork, null, "cancel clears selection")
        connector.finish("", "Authentication failed", 10)
        t.equal(state.connectionMessage, "Connection failed. Check your password and try again.", "connection failure message")
        t.equal(state.errorMessage, "Authentication failed", "connection stderr preserved")
        scan.finish("malformed\n")
        t.equal(state.networks.length, 0, "malformed scan retains original empty behavior")
        t.verify(!state.wifiEnabled, "malformed radio reports off")
        Shared.Theme.block = "#204060"
      },
      () => {
        t.equal(String(first.panel.surfaceColor), "#204060", "Theme updates actual popup background")
        Shared.Theme.block = originalBlock
      },
      () => t.equal(String(first.panel.surfaceColor), String(originalBlock), "popup Theme baseline restored")
    ]
  }
}
