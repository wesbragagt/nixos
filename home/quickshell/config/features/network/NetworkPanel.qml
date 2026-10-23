import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../shared" as Shared

PopupWindow {
  id: panel
  required property var networkState
  required property var hostWindow
  property var selectedNetwork: null
  property alias password: passwordInput.text
  property alias revealPassword: reveal.checked
  readonly property bool focusRequired: visible
  readonly property string emptyMessage: !networkState.wifiEnabled ? "Wi-Fi is off" : networkState.loading ? "Scanning…" : "No visible Wi-Fi networks"
  readonly property color surfaceColor: background.color
  property int demandToken: 0
  implicitWidth: 360
  implicitHeight: Math.min(600, content.implicitHeight + 32)
  color: "transparent"
  anchor.window: hostWindow

  function clearCredentials() { passwordInput.clear(); reveal.checked = false }
  function selectNetwork(network) {
    if (network.active || networkState.connecting) return
    selectedNetwork = network
    networkState.clearMessages()
    clearCredentials()
    passwordInput.forceActiveFocus()
  }
  function cancelSelection() {
    clearCredentials()
    networkState.dismissConnectionMessage()
    selectedNetwork = null
  }
  function connectSelected() {
    if (!selectedNetwork || networkState.connecting) return false
    const accepted = networkState.connectNetwork(selectedNetwork, passwordInput.text)
    clearCredentials()
    return accepted
  }
  onVisibleChanged: {
    if (visible) {
      if (!demandToken) demandToken = networkState.openPopup()
      focusTimer.start()
    } else {
      if (demandToken) networkState.closePopup(demandToken)
      demandToken = 0
      focusTimer.stop()
      focusGrab.active = false
      clearCredentials()
      selectedNetwork = null
    }
  }
  Component.onDestruction: if (demandToken) networkState.closePopup(demandToken)
  Connections {
    target: panel.networkState
    function onConnected(ssid) {
      if (panel.selectedNetwork && panel.selectedNetwork.ssid === ssid) panel.selectedNetwork = null
    }
  }
  HyprlandFocusGrab {
    id: focusGrab
    windows: [panel, panel.hostWindow]
    onCleared: panel.visible = false
  }
  Timer { id: focusTimer; interval: 150; onTriggered: if (panel.visible) focusGrab.active = true }

  component PanelButton: Button {
    id: control
    implicitHeight: 32
    leftPadding: 12
    rightPadding: 12
    contentItem: Text {
      text: control.text
      color: control.enabled ? Shared.Theme.foreground : Shared.Theme.muted
      font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.smallFontSize }
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
      radius: 6
      color: control.down ? Shared.Theme.pressed : control.hovered ? Shared.Theme.hover : Shared.Theme.surface
      border.color: Shared.Theme.hover
    }
  }
  Rectangle {
    id: background
    anchors.fill: parent
    radius: 12
    color: Shared.Theme.block
    border.color: Shared.Theme.hover
    ColumnLayout {
      id: content
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
      spacing: 12
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Internet"; color: Shared.Theme.foreground
          font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.headingFontSize; bold: true }
          Layout.fillWidth: true
        }
        PanelButton { text: "Refresh"; enabled: !panel.networkState.loading; onClicked: panel.networkState.refreshNetworks() }
        PanelButton { text: "×"; onClicked: panel.visible = false }
      }
      Text {
        text: panel.networkState.connection; color: Shared.Theme.green
        font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.fontSize }
        elide: Text.ElideRight; Layout.fillWidth: true
      }
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Wi-Fi"; color: Shared.Theme.foreground; Layout.fillWidth: true
          font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.iconFontSize }
        }
        Switch {
          checked: panel.networkState.wifiEnabled
          enabled: !panel.networkState.radioBusy && !panel.networkState.loading && !panel.networkState.connecting
          onClicked: panel.networkState.toggleRadio()
        }
      }
      Text {
        visible: text.length > 0; text: panel.networkState.errorMessage; color: Shared.Theme.pink
        wrapMode: Text.Wrap; Layout.fillWidth: true
        font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.fontSize }
      }
      ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(300, networkList.implicitHeight)
        visible: panel.networkState.wifiEnabled && panel.networkState.networks.length > 0
        clip: true
        contentWidth: availableWidth
        Column {
          id: networkList
          width: parent.width
          spacing: 6
          Repeater {
            model: panel.networkState.networks
            Rectangle {
              required property var modelData
              width: networkList.width; height: 58; radius: 7
              color: mouse.containsMouse ? Shared.Theme.hover : Shared.Theme.surface
              Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 4
                Text {
                  width: parent.width; text: (modelData.active ? "✓ " : "") + modelData.ssid
                  color: modelData.active ? Shared.Theme.green : Shared.Theme.foreground
                  elide: Text.ElideRight
                  font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.networkFontSize }
                }
                Text {
                  text: modelData.signal + "% signal · " + (modelData.security || "Open") + (modelData.active ? " · Connected" : "")
                  color: Shared.Theme.blue
                  font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.smallFontSize }
                }
              }
              MouseArea {
                id: mouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: panel.selectNetwork(modelData)
              }
            }
          }
        }
      }
      Rectangle {
        visible: panel.selectedNetwork !== null; Layout.fillWidth: true
        implicitHeight: credentials.implicitHeight + 24; radius: 8
        color: Shared.Theme.surface; border.color: Shared.Theme.pressed
        ColumnLayout {
          id: credentials
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 10
          Text {
            text: panel.selectedNetwork ? "Connect to " + panel.selectedNetwork.ssid : ""
            color: Shared.Theme.foreground; elide: Text.ElideRight; Layout.fillWidth: true
            font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.networkFontSize; bold: true }
          }
          TextField {
            id: passwordInput
            visible: panel.selectedNetwork !== null && panel.selectedNetwork.security !== "" && panel.selectedNetwork.security !== "--"
            Layout.fillWidth: true; implicitHeight: 40
            placeholderText: "Wi-Fi password"; placeholderTextColor: Shared.Theme.placeholder
            color: Shared.Theme.foreground; selectionColor: Shared.Theme.pressed
            echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
            enabled: !panel.networkState.connecting; selectByMouse: true; leftPadding: 12
            font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.iconFontSize }
            background: Rectangle {
              radius: 6; color: Shared.Theme.inputBackground
              border.color: passwordInput.activeFocus ? Shared.Theme.blue : Shared.Theme.hover
            }
            onAccepted: panel.connectSelected()
          }
          RowLayout {
            Layout.fillWidth: true
            CheckBox {
              id: reveal
              visible: passwordInput.visible; enabled: !panel.networkState.connecting; spacing: 8
              indicator: Rectangle {
                implicitWidth: 16; implicitHeight: 16
                x: reveal.leftPadding; y: (reveal.height - height) / 2; radius: 4
                color: reveal.checked ? Shared.Theme.blue : Shared.Theme.inputBackground
                border.color: Shared.Theme.blue
                Text {
                  anchors.centerIn: parent; text: reveal.checked ? "✓" : ""; color: Shared.Theme.block
                  font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.fontSize }
                }
              }
              contentItem: Text {
                text: "Show password"; leftPadding: reveal.indicator.width + reveal.spacing; rightPadding: 0
                color: Shared.Theme.blue; verticalAlignment: Text.AlignVCenter
                font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.smallFontSize }
              }
            }
            Item { Layout.fillWidth: true }
            PanelButton { text: "Cancel"; enabled: !panel.networkState.connecting; onClicked: panel.cancelSelection() }
            PanelButton { text: panel.networkState.connecting ? "Connecting…" : "Connect"; enabled: !panel.networkState.connecting; onClicked: panel.connectSelected() }
          }
        }
      }
      Text {
        visible: text !== ""; text: panel.networkState.connectionMessage
        color: panel.networkState.errorMessage ? Shared.Theme.pink : Shared.Theme.green
        wrapMode: Text.Wrap; Layout.fillWidth: true
        font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.fontSize }
      }
      Text {
        visible: !panel.networkState.wifiEnabled || panel.networkState.networks.length === 0
        text: panel.emptyMessage; color: Shared.Theme.blue
        font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.fontSize }
      }
      PanelButton { text: "All connection settings…"; Layout.fillWidth: true; onClicked: panel.networkState.openSettings() }
    }
  }
}
