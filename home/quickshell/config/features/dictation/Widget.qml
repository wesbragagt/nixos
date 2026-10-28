import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../shared" as Shared

Shared.Badge {
  id: widget
  required property var featureState
  required property var popupHostWindow
  // The keywords editor needs keyboard focus on the bar surface.
  readonly property bool focusRequired: popup.visible
  visible: featureState.featureEnabled
  icon: ""
  value: !featureState.available ? "?" : featureState.recording ? "REC" : featureState.language
  accent: !featureState.available ? Shared.Theme.muted : featureState.recording ? Shared.Theme.pink : Shared.Theme.blue
  border.width: featureState.recording ? 1 : 0
  border.color: Shared.Theme.pink
  tooltipText: "Hold Mod+D to dictate"
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.visible = !popup.visible
  }

  component Heading: Text {
    color: Shared.Theme.muted
    font.family: Shared.Theme.fontFamily
    font.pixelSize: Shared.Theme.smallFontSize
  }
  component Choice: RowLayout {
    id: choice
    required property var options
    required property string current
    signal picked(string value)
    Repeater {
      model: choice.options
      Shared.OptionButton {
        required property var modelData
        text: modelData.label
        selected: choice.current === modelData.value
        enabled: !widget.featureState.busy
        onClicked: choice.picked(modelData.value)
      }
    }
  }

  PopupWindow {
    id: popup
    anchor.window: widget.popupHostWindow
    anchor.rect.x: widget.popupHostWindow ? Math.max(0, Math.min(widget.popupHostWindow.width - width - 14, widget.mapToItem(widget.popupHostWindow.contentItem, 0, 0).x)) : 0
    anchor.rect.y: widget.popupHostWindow ? widget.popupHostWindow.height + 8 : 0
    implicitWidth: 420
    implicitHeight: content.implicitHeight + 32
    color: "transparent"
    onVisibleChanged: {
      if (visible) {
        widget.featureState.refresh()
        keywordsInput.text = widget.featureState.keywords.join("\n")
        focusTimer.start()
      } else { focusTimer.stop(); focusGrab.active = false }
    }
    HyprlandFocusGrab {
      id: focusGrab
      windows: [popup, widget.popupHostWindow]
      onCleared: popup.visible = false
    }
    Timer { id: focusTimer; interval: 150; onTriggered: if (popup.visible) focusGrab.active = true }
    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Shared.Theme.block
      ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10
        Text {
          text: "Dictation · Whistle"
          color: Shared.Theme.foreground
          font.family: Shared.Theme.fontFamily
          font.pixelSize: Shared.Theme.fontSize
        }
        Text {
          visible: !widget.featureState.available
          text: "dictate command unavailable"
          color: Shared.Theme.pink
          font.family: Shared.Theme.fontFamily
          font.pixelSize: Shared.Theme.smallFontSize
        }

        Heading { text: "Language" }
        Flow {
          Layout.fillWidth: true
          spacing: 4
          Repeater {
            model: widget.featureState.languages
            Shared.OptionButton {
              required property string modelData
              text: modelData
              selected: widget.featureState.language === modelData
              enabled: !widget.featureState.busy
              onClicked: widget.featureState.setOption("language", modelData)
            }
          }
        }

        Heading { text: "Speed" }
        Choice {
          options: [{ label: "Accurate", value: "full" }, { label: "Balanced", value: "4" }, { label: "Fast", value: "2" }]
          current: widget.featureState.depth
          onPicked: value => widget.featureState.setOption("depth", value)
        }

        Heading { text: "Output" }
        Choice {
          options: [{ label: "Type into window", value: "type" }, { label: "Copy to clipboard", value: "copy" }]
          current: widget.featureState.insert
          onPicked: value => widget.featureState.setOption("insert", value)
        }

        Heading { text: "Microphone" }
        ComboBox {
          id: micPicker
          Layout.fillWidth: true
          implicitHeight: 30
          enabled: !widget.featureState.busy
          textRole: "description"
          valueRole: "name"
          model: [{ name: "default", description: "System default" }].concat(widget.featureState.mics)
          currentIndex: Math.max(0, indexOfValue(widget.featureState.mic))
          onActivated: widget.featureState.setOption("mic", currentValue)
          contentItem: Text {
            leftPadding: 12
            text: micPicker.displayText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: micPicker.enabled ? Shared.Theme.foreground : Shared.Theme.muted
            font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.smallFontSize }
          }
          indicator: Text {
            x: micPicker.width - width - 12
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf078"
            color: Shared.Theme.muted
            font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.smallFontSize }
          }
          background: Rectangle {
            radius: 6
            color: micPicker.hovered ? Shared.Theme.hover : Shared.Theme.surface
            border.color: micPicker.popup.visible ? Shared.Theme.blue : Shared.Theme.hover
          }
          delegate: ItemDelegate {
            id: micOption
            required property var modelData
            required property int index
            width: micPicker.width
            highlighted: micPicker.highlightedIndex === index
            contentItem: Text {
              text: micOption.modelData.description
              elide: Text.ElideRight
              color: micPicker.currentIndex === micOption.index ? Shared.Theme.blue : Shared.Theme.foreground
              font { family: Shared.Theme.fontFamily; pixelSize: Shared.Theme.smallFontSize; bold: micPicker.currentIndex === micOption.index }
            }
            background: Rectangle { radius: 4; color: micOption.highlighted ? Shared.Theme.hover : "transparent" }
          }
          popup.background: Rectangle { radius: 6; color: Shared.Theme.block; border.color: Shared.Theme.hover }
        }

        Heading { text: "Custom words, one per line" }
        ScrollView {
          Layout.fillWidth: true
          Layout.preferredHeight: 90
          ScrollBar.vertical: Shared.ThemedScrollBar {}
          TextArea {
            id: keywordsInput
            placeholderText: "Krzysztof\nNixOS\nHyprland"
            placeholderTextColor: Shared.Theme.placeholder
            color: Shared.Theme.foreground
            selectionColor: Shared.Theme.pressed
            selectByMouse: true
            font.family: Shared.Theme.fontFamily
            font.pixelSize: Shared.Theme.smallFontSize
            background: Rectangle {
              radius: 6
              color: Shared.Theme.inputBackground
              border.color: keywordsInput.activeFocus ? Shared.Theme.blue : Shared.Theme.hover
            }
          }
        }
        Shared.OptionButton {
          text: "Save words"
          enabled: !widget.featureState.busy && keywordsInput.text !== widget.featureState.keywords.join("\n")
          onClicked: widget.featureState.setKeywords(keywordsInput.text)
        }

        Heading { text: "Recent" }
        Repeater {
          model: widget.featureState.history.slice(0, 5)
          Text {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.text
            elide: Text.ElideRight
            color: Shared.Theme.foreground
            font.family: Shared.Theme.fontFamily
            font.pixelSize: Shared.Theme.smallFontSize
          }
        }
        Heading {
          visible: widget.featureState.history.length === 0
          text: "No dictations yet"
        }
      }
    }
  }
}
