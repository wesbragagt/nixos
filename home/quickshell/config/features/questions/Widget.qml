import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../shared" as Shared

Item {
  id: root
  required property var featureState
  signal closeRequested()
  property alias input: questionInput
  property alias answerEdit: answerText
  property alias answerScroll: answerViewport
  property var openLink: function(url) { Qt.openUrlExternally(url) }
  property string renderedAnswer: ""
  property int _renderRevision: 0
  readonly property string statusText: {
    switch (featureState.phase) {
    case "starting": case "initializing": case "creating": return "Connecting…"
    case "cancelling": case "closing": return "Stopping…"
    case "answering": return featureState.toolActivity ? "Searching…" : "Writing…"
    default: return ""
    }
  }
  readonly property string outcomeText: {
    switch (featureState.outcome) {
    case "completed": return "Complete"
    case "incomplete": return "Incomplete — the answer may be partial."
    case "cancelled": return "Cancelled"
    case "refused": return "OMP declined this question."
    default: return ""
    }
  }

  function focusInput() { questionInput.forceActiveFocus(Qt.OtherFocusReason) }
  function submitQuestion() {
    if (questionInput.inputMethodComposing || featureState.busy) return false
    const accepted = featureState.submit(questionInput.text)
    if (accepted) focusInput()
    return accepted
  }
  function newQuestion() {
    if (!featureState.clear()) return false
    questionInput.clear()
    resetAnswer()
    focusInput()
    return true
  }
  function activateLink(link) {
    const url = String(link)
    if (!/^https?:\/\//i.test(url)) return false
    openLink(url)
    return true
  }
  function resetAnswer() {
    renderTimer.stop()
    ++_renderRevision
    renderedAnswer = ""
    answerViewport.contentY = 0
  }
  function queueAnswer() {
    if (!featureState.busy) flushAnswer()
    else if (!renderTimer.running) renderTimer.start()
  }
  function flushAnswer() {
    renderTimer.stop()
    if (renderedAnswer === featureState.answer) return
    const previousY = answerViewport.contentY
    const follow = answerViewport.contentHeight - answerViewport.height - previousY <= 24
    const revision = ++_renderRevision
    renderedAnswer = featureState.answer
    // TextEdit lays out Markdown after its text binding updates. Restore only
    // after that layout, without moving a reader who has scrolled away.
    Qt.callLater(function() {
      if (revision !== root._renderRevision) return
      const bottom = Math.max(0, answerViewport.contentHeight - answerViewport.height)
      answerViewport.contentY = follow ? bottom : Math.max(0, Math.min(previousY, bottom))
    })
  }
  function copyAnswer() {
    flushAnswer()
    if (!renderedAnswer) return false
    const focused = root.Window.window ? root.Window.window.activeFocusItem : null
    const start = answerText.selectionStart
    const end = answerText.selectionEnd
    const cursor = answerText.cursorPosition
    const previousY = answerViewport.contentY
    answerText.selectAll()
    answerText.copy()
    if (cursor === start) answerText.select(end, start)
    else answerText.select(start, end)
    if (focused) focused.forceActiveFocus(Qt.OtherFocusReason)
    Qt.callLater(function() {
      answerViewport.contentY = Math.max(0, Math.min(previousY,
        Math.max(0, answerViewport.contentHeight - answerViewport.height)))
    })
    return true
  }

  Keys.onEscapePressed: event => { root.closeRequested(); event.accepted = true }
  Shortcut {
    sequence: "Escape"
    context: Qt.WindowShortcut
    enabled: root.visible
    onActivated: root.closeRequested()
  }
  Timer { id: renderTimer; interval: 50; onTriggered: root.flushAnswer() }
  Connections {
    target: root.featureState
    function onAnswerChanged() { root.queueAnswer() }
    function onPhaseChanged() {
      if (root.featureState.phase === "starting") root.resetAnswer()
      if (!root.featureState.busy || root.featureState.phase === "closing") root.flushAnswer()
    }
    function onQuestionChanged() {
      if (questionInput.text !== root.featureState.question)
        questionInput.text = root.featureState.question
    }
  }
  Component.onCompleted: {
    questionInput.text = featureState.question
    flushAnswer()
  }

  component PanelButton: Button {
    id: control
    property bool primary: false
    implicitHeight: 32
    leftPadding: 12
    rightPadding: 12
    focusPolicy: Qt.StrongFocus
    contentItem: Text {
      text: control.text
      color: !control.enabled ? Shared.Theme.muted : control.primary ? Shared.Theme.block : Shared.Theme.foreground
      font { family: Shared.Theme.fontFamily; pixelSize: 12 }
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
      radius: 6
      color: control.down ? Shared.Theme.pressed
        : control.hovered ? Shared.Theme.hover
        : control.primary && control.enabled ? Shared.Theme.blue : Shared.Theme.surface
      border.color: control.visualFocus ? Shared.Theme.blue : Shared.Theme.hover
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Shared.Theme.block
    border.color: Shared.Theme.hover
    ColumnLayout {
      anchors { fill: parent; margins: 24 }
      spacing: 12
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          spacing: 4
          Layout.fillWidth: true
          Text {
            text: "Ask OMP"
            color: Shared.Theme.foreground
            font { family: Shared.Theme.fontFamily; pixelSize: 20; bold: true }
          }
          Text {
            text: "Web only · History saved"
            color: Shared.Theme.muted
            font { family: Shared.Theme.fontFamily; pixelSize: 12 }
          }
        }
        PanelButton { text: "Close"; onClicked: root.closeRequested() }
      }
      ScrollView {
        id: inputViewport
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(132, Math.max(84, questionInput.implicitHeight))
        Layout.minimumHeight: 48
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        TextArea {
          id: questionInput
          objectName: "questionInput"
          placeholderText: "Ask a quick question…"
          placeholderTextColor: Shared.Theme.placeholder
          textFormat: TextEdit.PlainText
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          selectByKeyboard: true
          KeyNavigation.tab: askButton
          KeyNavigation.priority: KeyNavigation.BeforeItem
          persistentSelection: true
          readOnly: root.featureState.busy
          color: Shared.Theme.foreground
          selectionColor: Shared.Theme.blue
          selectedTextColor: Shared.Theme.block
          padding: 12
          font { family: Shared.Theme.fontFamily; pixelSize: 15 }
          Accessible.name: "Question"
          background: Rectangle {
            radius: 6
            color: Shared.Theme.inputBackground
            border.color: questionInput.activeFocus ? Shared.Theme.blue : Shared.Theme.hover
          }
          onTextChanged: if (root.featureState.question !== text) root.featureState.question = text
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
              root.closeRequested()
              event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                       && !(event.modifiers & Qt.ShiftModifier) && !inputMethodComposing) {
              root.submitQuestion()
              event.accepted = true
            }
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        PanelButton {
          id: askButton
          text: "Ask"; primary: true
          enabled: !root.featureState.busy && questionInput.text.trim().length > 0
          onClicked: root.submitQuestion()
        }
        PanelButton {
          text: "Stop"; visible: root.featureState.busy
          enabled: root.featureState.phase !== "cancelling" && root.featureState.phase !== "closing"
          onClicked: root.featureState.cancel()
        }
        PanelButton { text: "New question"; enabled: !root.featureState.busy; onClicked: root.newQuestion() }
        Item { Layout.fillWidth: true }
        PanelButton {
          text: "Copy answer"; enabled: root.featureState.answer.length > 0
          // A mouse copy should not steal the question/answer's keyboard focus.
          focusPolicy: Qt.TabFocus
          onClicked: root.copyAnswer()
        }
      }
      Text {
        Layout.fillWidth: true
        visible: root.statusText.length > 0
        text: root.statusText
        color: Shared.Theme.muted
        font { family: Shared.Theme.fontFamily; pixelSize: 12 }
      }
      Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.featureState.toolActivity
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Shared.Theme.muted
        font { family: Shared.Theme.fontFamily; pixelSize: 12 }
      }
      Flickable {
        id: answerViewport
        objectName: "answerScroll"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 24
        clip: true
        contentWidth: width
        contentHeight: answerText.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
          contentItem: Rectangle { implicitWidth: 5; radius: 3; color: Shared.Theme.hover }
        }
        TextEdit {
          id: answerText
          objectName: "answerEdit"
          width: Math.max(1, answerViewport.width - 16)
          height: Math.max(answerViewport.height, contentHeight)
          text: root.renderedAnswer
          textFormat: TextEdit.MarkdownText
          readOnly: true
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          selectByKeyboard: true
          activeFocusOnTab: true
          persistentSelection: true
          color: Shared.Theme.foreground
          selectionColor: Shared.Theme.blue
          selectedTextColor: Shared.Theme.block
          palette.link: Shared.Theme.blue
          font { family: Shared.Theme.fontFamily; pixelSize: 15 }
          Accessible.name: "OMP answer"
          onLinkActivated: link => root.activateLink(link)
        }
        Text {
          anchors { left: parent.left; top: parent.top; right: parent.right }
          visible: !root.renderedAnswer && !root.featureState.busy && !root.featureState.error && !root.featureState.outcome
          text: "Ask a question. Read the answer here."
          wrapMode: Text.Wrap
          color: Shared.Theme.muted
          font { family: Shared.Theme.fontFamily; pixelSize: 15 }
        }
      }
      Text {
        Layout.fillWidth: true
        Layout.maximumHeight: 80
        visible: text.length > 0
        text: root.featureState.error
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        color: Shared.Theme.pink
        font { family: Shared.Theme.fontFamily; pixelSize: 12 }
      }
      Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.outcomeText
        textFormat: Text.PlainText
        color: Shared.Theme.muted
        wrapMode: Text.Wrap
        font { family: Shared.Theme.fontFamily; pixelSize: 12 }
      }
      Text {
        Layout.fillWidth: true
        text: "Enter to ask · Shift+Enter for a new line · Esc to close"
        wrapMode: Text.Wrap
        color: Shared.Theme.muted
        font { family: Shared.Theme.fontFamily; pixelSize: 12 }
      }
    }
  }
}
