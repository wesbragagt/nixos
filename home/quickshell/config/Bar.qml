// Run with qs on Hyprland. Icons use JetBrainsMono Nerd Font.
// Status commands use wpctl, nmcli, and bluetoothctl from PATH.
// Volume: left-click opens pavucontrol Playback; right-click mutes; scroll adjusts.
// Idle badge shares idle-control with the Hyprland keyboard shortcut.
// Microphone badge uses transcribe status/toggle; the existing service owns recording.
// Network badge opens nearby Wi-Fi options; nmcli handles connection authentication.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
  id: bar
  WlrLayershell.keyboardFocus: networkPanel.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 32
  color: "transparent"

  readonly property color blockColor: "#131c30"
  readonly property color foreground: "#c5cfec"
  readonly property color blue: "#89b4fa"
  readonly property color pink: "#f5a9b8"
  readonly property color green: "#a6d5bc"
  property int cpu: 0
  property int memory: 0
  property int disk: 0
  property int temperature: -1
  property int volume: 0
  property bool muted: false
  property string networkType: ""
  property bool bluetooth: false
  property double previousTotal: 0
  property double previousIdle: 0
  property string transcriptionState: "unknown"
  readonly property bool transcribeEnabled: Quickshell.env("QUICKSHELL_TRANSCRIBE") === "1"
  property bool idleEnabled: true

  component Label: Text {
    color: bar.foreground
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12
    verticalAlignment: Text.AlignVCenter
  }

  component Badge: Rectangle {
    id: badge
    property string icon
    property string value: ""
    property color accent: bar.blue
    property int horizontalPadding: 10
    implicitWidth: contents.implicitWidth + horizontalPadding * 2
    implicitHeight: 24
    radius: 5
    color: bar.blockColor

    Row {
      id: contents
      anchors.centerIn: parent
      spacing: 7

      Label {
        text: badge.icon
        color: badge.accent
        font.pixelSize: 14
        height: 24
      }

      Label {
        text: badge.value
        visible: text.length > 0
        height: 24
      }
    }
  }

  Row {
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    spacing: 20

    Badge {
      icon: "\uf313"
      accent: "#89bfd4"
      horizontalPadding: 12
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exec", "foot"])
      }
    }

    Badge { icon: "\uf4bc"; value: bar.cpu + "%"; accent: bar.pink }
    Badge { icon: "\uefc5"; value: bar.memory + "%"; accent: "#cba6f7" }
    Badge { icon: "\uf0a0"; value: bar.disk + "%"; accent: "#f9e2af" }
  }

  Row {
    anchors.centerIn: parent
    spacing: 0

    Rectangle {
      width: workspaceRow.implicitWidth + 16
      height: 24
      radius: 5
      color: bar.blockColor

      Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
          model: Hyprland.workspaces

          Rectangle {
            required property var modelData
            readonly property bool active: Hyprland.focusedWorkspace === modelData
            width: 42
            height: 24
            radius: 4
            color: active ? "#304161" : "transparent"

            Label {
              anchors.centerIn: parent
              text: modelData.name
              color: parent.active ? "#f5c2e7" : bar.foreground
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: modelData.activate()
            }
          }
        }
      }
    }
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    spacing: 20

    Badge {
      icon: bar.muted ? "\uf026" : "\uf028"
      value: bar.muted ? "mute" : bar.volume + "%"
      accent: "#f9e2af"
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton)
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
          else
            Quickshell.execDetached(["pavucontrol", "--tab=1"])
        }
        onWheel: event => Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", event.angleDelta.y > 0 ? "5%+" : "5%-"])
      }
    }

    Badge {
      icon: "\uf0f4"
      value: bar.idleEnabled ? "idle" : "awake"
      accent: bar.idleEnabled ? bar.blue : bar.green
      border.width: bar.idleEnabled ? 0 : 1
      border.color: bar.green
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!idleToggle.running) idleToggle.running = true
      }
    }

    Badge {
      visible: bar.transcribeEnabled
      icon: bar.transcriptionState === "disabled" ? "\uf131" : "\uf130"
      value: bar.transcriptionState === "recording" ? "REC"
        : bar.transcriptionState === "enabled" ? "auto"
        : bar.transcriptionState === "disabled" ? "off" : "?"
      accent: bar.transcriptionState === "recording" ? bar.pink
        : bar.transcriptionState === "enabled" ? bar.green : "#66728d"
      border.width: bar.transcriptionState === "recording" ? 1 : 0
      border.color: bar.pink
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!transcriptionToggle.running) transcriptionToggle.running = true
      }
    }

    Badge {
      id: networkBadge
      icon: bar.networkType === "ethernet" ? "\uf0e8"
        : bar.networkType === "wifi" ? "\uf1eb" : "\uf071"
      accent: bar.networkType ? bar.green : bar.pink
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: networkPanel.visible = !networkPanel.visible
      }
    }

    NetworkPanel {
      id: networkPanel
      anchor.window: bar
      anchor.rect.x: Math.min(bar.width - width - 14, networkBadge.mapToItem(bar.contentItem, 0, 0).x)
      anchor.rect.y: bar.height + 8
    }
    Badge { icon: "\uf293"; accent: bar.bluetooth ? bar.blue : "#66728d" }

    Badge {
      icon: "\uf017"
      value: Qt.formatDateTime(clock.date, "ddd, dd MMM, hh:mm AP")
      accent: bar.green
    }

    Badge {
      icon: "\uf2c9"
      value: bar.temperature < 0 ? "N/A" : String(bar.temperature)
      accent: "#fab387"
    }

    Badge {
      icon: "\uf011"
      accent: bar.pink
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["loginctl", "lock-session"])
      }
    }
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  Process {
    id: idleStatus
    command: ["idle-control", "status"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: bar.idleEnabled = JSON.parse(text).class === "enabled"
    }
  }

  Process {
    id: idleToggle
    command: ["idle-control", "toggle"]
    onExited: if (!idleStatus.running) idleStatus.running = true
  }

  Process {
    id: transcriptionStatus
    command: ["transcribe", "status"]
    running: bar.transcribeEnabled
    stdout: StdioCollector {
      onStreamFinished: bar.transcriptionState = JSON.parse(text).class
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) bar.transcriptionState = "unknown"
    }
  }

  Process {
    id: transcriptionToggle
    command: ["transcribe", "toggle"]
    onExited: (exitCode, exitStatus) => {
      if (!transcriptionStatus.running) transcriptionStatus.running = true
    }
  }

  Process {
    id: stats
    running: true
    command: ["sh", "-c", `
      read tag user nice system idle iowait irq softirq steal rest < /proc/stat
      printf '%s %s\\n' "$((user+nice+system+idle+iowait+irq+softirq+steal))" "$((idle+iowait))"
      cat /proc/meminfo
      df -P / | tail -n 1
      for sensor in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$sensor" ]; then printf 'TEMP '; cat "$sensor"; break; fi
      done
      printf 'AUDIO '; wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null
      printf '\\nNETWORK\\n'
      nmcli -t -f TYPE,STATE device status
      printf '\\nBLUETOOTH '; bluetoothctl show 2>/dev/null
    `]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n")
        const ticks = lines[0].trim().split(/\s+/).map(Number)
        const elapsed = ticks[0] - bar.previousTotal
        if (bar.previousTotal > 0 && elapsed > 0)
          bar.cpu = Math.round(100 * (1 - (ticks[1] - bar.previousIdle) / elapsed))
        bar.previousTotal = ticks[0]
        bar.previousIdle = ticks[1]
        const total = text.match(/MemTotal:\s+(\d+)/)
        const available = text.match(/MemAvailable:\s+(\d+)/)
        if (total && available)
          bar.memory = Math.round(100 * (1 - Number(available[1]) / Number(total[1])))
        const disk = text.match(/^\S+\s+\d+\s+\d+\s+\d+\s+(\d+)%/m)
        if (disk) bar.disk = Number(disk[1])
        const temperature = text.match(/TEMP (\d+)/)
        bar.temperature = temperature ? Math.round(Number(temperature[1]) / 1000) : -1
        const audio = text.match(/AUDIO Volume:\s+([\d.]+)([^\n]*)/)
        if (audio) {
          bar.volume = Math.round(Number(audio[1]) * 100)
          bar.muted = audio[2].includes("MUTED")
        }
        bar.networkType = /^ethernet:connected$/m.test(text) ? "ethernet"
          : /^wifi:connected$/m.test(text) ? "wifi" : ""
        bar.bluetooth = /Powered: yes/.test(text)
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      if (!stats.running) stats.running = true
      if (!idleStatus.running) idleStatus.running = true
      if (bar.transcribeEnabled && !transcriptionStatus.running) transcriptionStatus.running = true
    }
  }
}
