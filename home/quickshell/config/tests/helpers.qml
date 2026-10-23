import QtQuick
import Quickshell
import "../shared" as Shared

ShellRoot {
  property bool captured: false
  property color originalBlock: Shared.Theme.block
  property color originalForeground: Shared.Theme.foreground
  property int originalSize: Shared.Theme.fontSize
  FloatingWindow {
    id: window
    visible: true
    implicitWidth: 360
    implicitHeight: 100
    color: "transparent"
    Row {
      id: surface
      anchors.centerIn: parent
      spacing: 12
      Shared.Badge { id: badge; icon: "CPU"; value: "42%"; tooltipText: "CPU details\nSecond line" }
      Shared.Label { id: label; text: "Shared text" }
    }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        t.equal(badge.height, 24, "baseline badge height")
        t.verify(badge.width > 60, "badge content fits")
        t.verify(badge.hostWindow === window, "helper resolves its actual host")
        t.equal(badge.tooltipWidthLimit, 344, "tooltip bound follows host width")
        Shared.Theme.block = "#204060"
        Shared.Theme.foreground = "#ffffff"
        Shared.Theme.fontSize = 18
      },
      () => {
        t.equal(String(badge.color), "#204060", "Theme updates badge background")
        t.equal(String(label.color), "#ffffff", "Theme updates text")
        t.equal(label.font.pixelSize, 18, "Theme updates text geometry")
        surface.grabToImage(result => {
          result.saveToFile("/tmp/quickshell-foundation-helpers.png")
          captured = true
        })
      },
      () => {
        if (!captured) return false
        Shared.Theme.block = originalBlock
        Shared.Theme.foreground = originalForeground
        Shared.Theme.fontSize = originalSize
      },
      () => {
        t.equal(String(badge.color), String(originalBlock), "baseline badge style restored")
        t.equal(label.font.pixelSize, originalSize, "baseline text size restored")
      }
    ]
  }
}
