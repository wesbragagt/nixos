import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Passwords reach nmcli over stdin, never through command arguments or temporary files.
PopupWindow {
  id: panel
  property var networks: []
  property bool wifiEnabled: false
  property string connection: "Checking connection…"
  property string errorMessage: ""
  property bool loading: scan.running
  property var selectedNetwork: null
  property string connectionMessage: ""
  property bool connecting: connector.running
  implicitWidth: 360
  implicitHeight: Math.min(600, content.implicitHeight + 32)
  color: "transparent"

  component PanelButton: Button {
    id: control
    implicitHeight: 32
    leftPadding: 12
    rightPadding: 12
    contentItem: Text {
      text: control.text
      color: control.enabled ? "#c5cfec" : "#66728d"
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
      radius: 6
      color: control.down ? "#40577c" : control.hovered ? "#304161" : "#1c2941"
      border.color: "#304161"
    }
  }

  function refresh() {
    if (!scan.running) scan.running = true
  }

  onVisibleChanged: {
    if (visible) { refresh(); focusTimer.start() }
    else {
      focusTimer.stop()
      focusGrab.active = false
      password.clear()
      revealPassword.checked = false
      if (!connecting) selectedNetwork = null
    }
  }

  function connectSelected() {
    if (!selectedNetwork || connecting) return
    errorMessage = ""
    connectionMessage = "Connecting to " + selectedNetwork.ssid + "…"
    connector.command = ["nmcli", "--colors", "no", "--wait", "30", "--ask", "device", "wifi", "connect", selectedNetwork.ssid]
    connector.stdinEnabled = true
    connector.running = true
  }

  HyprlandFocusGrab {
    id: focusGrab
    windows: [panel, panel.anchor.window]
    onCleared: panel.visible = false
  }

  Timer {
    id: focusTimer
    interval: 150
    onTriggered: if (panel.visible) focusGrab.active = true
  }

  Process {
    id: connector
    environment: ({ LC_ALL: "C" })
    onStarted: {
      write(password.text + "\n")
      stdinEnabled = false
      password.clear()
      revealPassword.checked = false
    }
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) panel.errorMessage = text.trim()
    }
    onExited: (code, status) => {
      panel.connectionMessage = code === 0 ? "Connected to " + panel.selectedNetwork.ssid : "Connection failed. Check your password and try again."
      if (code === 0) panel.selectedNetwork = null
      panel.refresh()
    }
  }

  Process {
    id: scan
    command: ["sh", "-c", "nmcli radio wifi; printf '\\nDEVICES\\n'; nmcli -t --escape no -f TYPE,STATE,CONNECTION device status; printf '\\nNETWORKS\\n'; nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto"]
    stdout: StdioCollector {
      onStreamFinished: {
        panel.wifiEnabled = text.split("\n")[0].trim() === "enabled"
        const sections = text.split("\nNETWORKS\n")
        const devices = sections[0].split("\n")
        const wired = devices.find(line => line.startsWith("ethernet:connected:"))
        const wireless = devices.find(line => line.startsWith("wifi:connected:"))
        panel.connection = wired ? "Ethernet · " + wired.substring(19)
          : wireless ? "Wi-Fi · " + wireless.substring(15) : "Not connected"
        const found = new Map()
        for (const line of (sections[1] || "").split("\n")) {
          const fields = line.split(":")
          if (fields.length < 4) continue
          const ssid = fields.slice(3).join(":")
          if (!ssid) continue
          const entry = { ssid: ssid, signal: Number(fields[1]), security: fields[2], active: fields[0] === "*" }
          const old = found.get(ssid)
          if (!old || entry.active || (!old.active && entry.signal > old.signal)) found.set(ssid, entry)
        }
        panel.networks = Array.from(found.values()).sort((a, b) => Number(b.active) - Number(a.active) || b.signal - a.signal)
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) panel.errorMessage = text.trim()
    }
  }

  Process {
    id: radio
    command: ["nmcli", "radio", "wifi", panel.wifiEnabled ? "off" : "on"]
    onExited: (code, status) => panel.refresh()
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) panel.errorMessage = text.trim()
    }
  }

  Timer {
    interval: 10000
    running: panel.visible
    repeat: true
    onTriggered: panel.refresh()
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: "#131c30"
    border.color: "#304161"

    ColumnLayout {
      id: content
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Internet"
          color: "#c5cfec"
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 16; bold: true }
          Layout.fillWidth: true
        }
        PanelButton { text: "Refresh"; enabled: !panel.loading; onClicked: { panel.errorMessage = ""; panel.refresh() } }
        PanelButton { text: "×"; onClicked: panel.visible = false }
      }

      Text {
        text: panel.connection
        color: "#a6d5bc"
        font.pixelSize: 12
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      RowLayout {
        Layout.fillWidth: true
        Text { text: "Wi-Fi"; color: "#c5cfec"; font.pixelSize: 14; Layout.fillWidth: true }
        Switch {
          checked: panel.wifiEnabled
          enabled: !radio.running && !panel.loading && !panel.connecting
          onClicked: { panel.errorMessage = ""; radio.running = true }
        }
      }

      Text {
        visible: panel.errorMessage.length > 0
        text: panel.errorMessage
        color: "#f5a9b8"
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        font.pixelSize: 12
      }

      ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(300, networkList.implicitHeight)
        visible: panel.wifiEnabled && panel.networks.length > 0
        clip: true
        contentWidth: availableWidth

        Column {
          id: networkList
          width: parent.width
          spacing: 6
          Repeater {
            model: panel.networks
            Rectangle {
              required property var modelData
              width: networkList.width
              height: 58
              radius: 7
              color: mouse.containsMouse ? "#304161" : "#1c2941"
              Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 4
                Text {
                  width: parent.width
                  text: (modelData.active ? "✓ " : "") + modelData.ssid
                  color: modelData.active ? "#a6d5bc" : "#c5cfec"
                  elide: Text.ElideRight
                  font.pixelSize: 13
                }
                Text {
                  text: modelData.signal + "% signal · " + (modelData.security || "Open") + (modelData.active ? " · Connected" : "")
                  color: "#89b4fa"
                  font.pixelSize: 11
                }
              }
              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!modelData.active && !panel.connecting) {
                    panel.selectedNetwork = modelData
                    panel.errorMessage = ""
                    panel.connectionMessage = ""
                    password.clear()
                    revealPassword.checked = false
                    password.forceActiveFocus()
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        visible: panel.selectedNetwork !== null
        Layout.fillWidth: true
        implicitHeight: credentials.implicitHeight + 24
        radius: 8
        color: "#1c2941"
        border.color: "#40577c"
        ColumnLayout {
          id: credentials
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 10
          Text {
            text: panel.selectedNetwork ? "Connect to " + panel.selectedNetwork.ssid : ""
            color: "#c5cfec"
            font { pixelSize: 13; bold: true }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          TextField {
            id: password
            visible: panel.selectedNetwork !== null && panel.selectedNetwork.security !== "" && panel.selectedNetwork.security !== "--"
            Layout.fillWidth: true
            implicitHeight: 40
            placeholderText: "Wi-Fi password"
            placeholderTextColor: "#8896b3"
            color: "#c5cfec"
            selectionColor: "#40577c"
            echoMode: revealPassword.checked ? TextInput.Normal : TextInput.Password
            enabled: !panel.connecting
            selectByMouse: true
            font.pixelSize: 14
            leftPadding: 12
            background: Rectangle {
              radius: 6
              color: "#101827"
              border.color: password.activeFocus ? "#89b4fa" : "#304161"
            }
            onAccepted: panel.connectSelected()
          }
          RowLayout {
            Layout.fillWidth: true
            CheckBox {
              id: revealPassword
              visible: password.visible
              enabled: !panel.connecting
              spacing: 8
              indicator: Rectangle {
                implicitWidth: 16
                implicitHeight: 16
                x: revealPassword.leftPadding
                y: (revealPassword.height - height) / 2
                radius: 4
                color: revealPassword.checked ? "#89b4fa" : "#101827"
                border.color: "#89b4fa"
                Text {
                  anchors.centerIn: parent
                  text: revealPassword.checked ? "✓" : ""
                  color: "#131c30"
                  font.pixelSize: 12
                }
              }
              contentItem: Text {
                text: "Show password"
                leftPadding: revealPassword.indicator.width + revealPassword.spacing
                rightPadding: 0
                color: "#89b4fa"
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
              }
            }
            Item { Layout.fillWidth: true }
            PanelButton {
              text: "Cancel"
              enabled: !panel.connecting
              onClicked: { password.clear(); panel.selectedNetwork = null; panel.connectionMessage = "" }
            }
            PanelButton {
              text: panel.connecting ? "Connecting…" : "Connect"
              enabled: !panel.connecting
              onClicked: panel.connectSelected()
            }
          }
        }
      }

      Text {
        visible: panel.connectionMessage !== ""
        text: panel.connectionMessage
        color: panel.errorMessage ? "#f5a9b8" : "#a6d5bc"
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        font.pixelSize: 12
      }

      Text {
        visible: !panel.wifiEnabled || panel.networks.length === 0
        text: !panel.wifiEnabled ? "Wi-Fi is off" : panel.loading ? "Scanning…" : "No visible Wi-Fi networks"
        color: "#89b4fa"
        font.pixelSize: 12
      }

      PanelButton {
        text: "All connection settings…"
        Layout.fillWidth: true
        onClicked: Quickshell.execDetached(["foot", "--title=Network settings", "nmtui"])
      }
    }
  }
}
