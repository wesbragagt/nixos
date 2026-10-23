import Quickshell
import QtQuick

Rectangle {
  id: badge
  property string icon
  property string value: ""
  property string tooltipText: ""
  property color accent: Theme.blue
  property int horizontalPadding: 10
  // Resolve the hosting window rather than reaching into a layout's private IDs.
  readonly property var hostWindow: QsWindow.window
  readonly property real tooltipWidthLimit: Math.max(1, hostWindow ? hostWindow.width - 16 : 404)
  readonly property real tooltipHeightLimit: Math.max(1, hostWindow && hostWindow.screen ? hostWindow.screen.height - 16 : 600)
  implicitWidth: contents.implicitWidth + horizontalPadding * 2
  implicitHeight: 24
  radius: 5
  color: Theme.block

  // Pointer observation must not consume the consumer's click/wheel gestures.
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
    implicitWidth: Math.min(420, badge.tooltipWidthLimit, tooltipLabel.implicitWidth + 24)
    implicitHeight: Math.min(tooltipLabel.implicitHeight + 20, badge.tooltipHeightLimit)
    color: "transparent"
    mask: Region {}

    Rectangle {
      anchors.fill: parent
      radius: 6
      color: Theme.block
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
      font.pixelSize: Theme.iconFontSize
      height: 24
    }
    Label {
      text: badge.value
      visible: text.length > 0
      height: 24
    }
  }
}
