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
  property int cpu: -1
  property int memory: -1
  property int disk: -1
  property string cpuModel: ""
  property int logicalCpus: 0
  property string cpuLoad: ""
  property double memoryTotal: -1
  property double memoryAvailable: -1
  property double diskTotal: -1
  property double diskUsed: -1
  property double diskAvailable: -1
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

  function formatSize(kib) {
    if (kib < 0) return "unavailable"
    return kib >= 1048576 ? (kib / 1048576).toFixed(1) + " GiB"
      : (kib / 1024).toFixed(1) + " MiB"
  }

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
    property string tooltipText: ""
    property color accent: bar.blue
    property int horizontalPadding: 10
    implicitWidth: contents.implicitWidth + horizontalPadding * 2
    implicitHeight: 24
    radius: 5
    color: bar.blockColor

    // HoverHandler observes the pointer without consuming badge clicks or wheel events.
    HoverHandler { id: badgeHover; enabled: badge.tooltipText.length > 0 }

    PopupWindow {
      id: tooltip
      visible: badgeHover.hovered && badge.tooltipText.length > 0
      anchor.item: badge
      anchor.rect.x: badge.width / 2
      anchor.rect.y: badge.height + 8
      anchor.rect.width: 1
      anchor.rect.height: 1
      anchor.edges: Edges.Top
      anchor.gravity: Edges.Bottom
      anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY | PopupAdjustment.SlideY
      implicitWidth: Math.min(420, Math.max(1, bar.width - 16), tooltipLabel.implicitWidth + 24)
      implicitHeight: Math.min(tooltipLabel.implicitHeight + 20, bar.screen.height - 16)
      color: "transparent"
      // Empty input region: no pointer interception and no focus grab.
      mask: Region {}

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: bar.blockColor
        border.color: badge.accent
        clip: true

        Label {
          id: tooltipLabel
          anchors.fill: parent
          anchors.margins: 10
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          text: badge.tooltipText
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
        }
      }
    }

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

    Badge {
      icon: "\uf4bc"
      value: bar.cpu < 0 ? "N/A" : bar.cpu + "%"
      accent: bar.pink
      tooltipText: "CPU usage: " + (bar.cpu < 0 ? "waiting for samples" : bar.cpu + "%")
        + "\nModel: " + (bar.cpuModel || "unavailable")
        + "\nLogical CPUs: " + (bar.logicalCpus || "unavailable")
        + "\nLoad (1 / 5 / 15 min): " + (bar.cpuLoad || "unavailable")
    }
    Badge {
      icon: "\uefc5"
      value: bar.memory < 0 ? "N/A" : bar.memory + "%"
      accent: "#cba6f7"
      tooltipText: "Memory: " + (bar.memory < 0 ? "unavailable" : bar.memory + "% used")
        + "\nUsed: " + bar.formatSize(bar.memoryTotal < 0 ? -1 : bar.memoryTotal - bar.memoryAvailable)
        + "\nAvailable: " + bar.formatSize(bar.memoryAvailable)
        + "\nTotal: " + bar.formatSize(bar.memoryTotal)
    }
    Badge {
      icon: "\uf0a0"
      value: bar.disk < 0 ? "N/A" : bar.disk + "%"
      accent: "#f9e2af"
      tooltipText: "Root filesystem (/): " + (bar.disk < 0 ? "unavailable" : bar.disk + "% used")
        + "\nUsed: " + bar.formatSize(bar.diskUsed)
        + "\nAvailable: " + bar.formatSize(bar.diskAvailable)
        + "\nTotal: " + bar.formatSize(bar.diskTotal)
    }
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

  // Hardware identity does not need to be reread on every two-second poll.
  Process {
    command: ["cat", "/proc/cpuinfo"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const model = text.match(/^(?:model name|Hardware)\s*:\s*(.+)$/m)
        bar.cpuModel = model ? model[1].trim() : ""
        const processors = text.match(/^processor\s*:/gm)
        bar.logicalCpus = processors ? processors.length : 0
      }
    }
  }

  Process {
    id: stats
    running: true
    environment: ({ LC_ALL: "C" })
    command: ["sh", "-c", `
      read tag user nice system idle iowait irq softirq steal rest < /proc/stat
      printf '%s %s\\n' "$((user+nice+system+idle+iowait+irq+softirq+steal))" "$((idle+iowait))"
      cat /proc/meminfo
      df -Pk / | tail -n 1
      read load1 load5 load15 rest < /proc/loadavg
      printf 'LOAD %s %s %s\\n' "$load1" "$load5" "$load15"
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
        bar.cpu = bar.previousTotal > 0 && elapsed > 0
          ? Math.max(0, Math.min(100, Math.round(100 * (1 - (ticks[1] - bar.previousIdle) / elapsed)))) : -1
        bar.previousTotal = ticks[0]
        bar.previousIdle = ticks[1]
        const load = text.match(/^LOAD ([\d.]+) ([\d.]+) ([\d.]+)$/m)
        bar.cpuLoad = load ? load.slice(1).join(" / ") : ""
        const total = text.match(/MemTotal:\s+(\d+)/)
        const available = text.match(/MemAvailable:\s+(\d+)/)
        const memoryReady = total && available && Number(total[1]) > 0
        bar.memoryTotal = memoryReady ? Number(total[1]) : -1
        bar.memoryAvailable = memoryReady ? Number(available[1]) : -1
        bar.memory = memoryReady ? Math.round(100 * (1 - bar.memoryAvailable / bar.memoryTotal)) : -1
        const disk = text.match(/^\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+\/$/m)
        bar.diskTotal = disk ? Number(disk[1]) : -1
        bar.diskUsed = disk ? Number(disk[2]) : -1
        bar.diskAvailable = disk ? Number(disk[3]) : -1
        bar.disk = disk ? Number(disk[4]) : -1
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
