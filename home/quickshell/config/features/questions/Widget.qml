import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../shared" as Shared
import "Markdown.js" as Markdown

Item {
  id: root
  required property var featureState
  signal closeRequested()
  property alias input: questionInput
  property alias answerEdit: answerText
  property alias answerScroll: answerViewport
  property var openLink: function(url) { featureState.openUrl(url) }
  property string renderedAnswer: ""
  property var history: History {}
  property bool historyVisible: false
  property var selectedHistory: null
  property alias historySearch: historySearchInput
  property alias historyList: historyResults
  readonly property string displayedAnswer: historyVisible ? (selectedHistory ? selectedHistory.answer : "") : featureState.answer
  readonly property string historyMessage: history.busy ? "Loading saved conversations…"
    : history.error ? history.error
    : history.results.length ? "" : history.query.trim() ? "No matching conversations." : "No saved conversations yet."
  readonly property color cardColor: Qt.tint(Shared.Theme.block, Qt.rgba(Shared.Theme.surface.r, Shared.Theme.surface.g, Shared.Theme.surface.b, 0.45))
  readonly property color chipColor: Qt.tint(cardColor, Qt.rgba(Shared.Theme.blue.r, Shared.Theme.blue.g, Shared.Theme.blue.b, 0.18))
  readonly property var markdownStyle: ({
    size: 15,
    background: String(cardColor),
    link: String(Shared.Theme.blue),
    accent: String(Shared.Theme.purple),
    rule: String(Shared.Theme.hover),
    chipBackground: String(chipColor),
    chipForeground: String(Shared.Theme.blue),
    codeBackground: String(Shared.Theme.inputBackground),
    codeForeground: String(Shared.Theme.green),
    calloutBackground: String(Qt.tint(cardColor, Qt.rgba(Shared.Theme.purple.r, Shared.Theme.purple.g, Shared.Theme.purple.b, 0.10))),
    calloutForeground: String(Shared.Theme.foreground),
    tableHeader: String(chipColor)
  })
  readonly property string footerGlyph: {
    if (historyVisible) return ""
    if (featureState.error || featureState.outcome === "refused") return "\uf057"
    if (statusText) return "\u25CF"
    switch (featureState.outcome) {
    case "completed": return "\uf058"
    case "incomplete": case "cancelled": return "\uf06a"
    default: return ""
    }
  }
  readonly property color footerColor: {
    if (featureState.error || featureState.outcome === "refused") return Shared.Theme.pink
    if (statusText) return Shared.Theme.blue
    return featureState.outcome === "completed" ? Shared.Theme.green : Shared.Theme.yellow
  }
  property int _renderRevision: 0
  readonly property string statusText: {
    if (historyVisible) return ""
    switch (featureState.phase) {
    case "starting": case "initializing": case "creating": return "Connecting…"
    case "cancelling": case "closing": return "Stopping…"
    case "answering": return featureState.toolActivity ? "Searching…" : "Writing…"
    default: return ""
    }
  }
  readonly property string outcomeText: {
    if (historyVisible) return ""
    switch (featureState.outcome) {
    case "completed": return "Complete"
    case "incomplete": return "Incomplete — the answer may be partial."
    case "cancelled": return "Cancelled"
    case "refused": return "OMP declined this question."
    default: return ""
    }
  }

  function focusInput() {
    if (historyVisible) historySearchInput.forceActiveFocus(Qt.OtherFocusReason)
    else questionInput.forceActiveFocus(Qt.OtherFocusReason)
  }
  function toggleHistory() {
    historyVisible = !historyVisible
    resetAnswer()
    flushAnswer()
    if (historyVisible) history.refresh()
    focusInput()
  }
  function selectHistory(entry) {
    if (!entry) return false
    selectedHistory = entry
    resetAnswer()
    flushAnswer()
    return true
  }
  function moveHistorySelection(delta) {
    const count = history.results.length
    if (!count) return
    historyResults.currentIndex = Math.max(0, Math.min(count - 1, historyResults.currentIndex + delta))
    historyResults.positionViewAtIndex(historyResults.currentIndex, ListView.Contain)
  }
  function chooseHistoryResult() {
    if (!history.results.length) return false
    return selectHistory(history.results[Math.max(0, historyResults.currentIndex)])
  }
  function historyDate(timestamp) {
    const date = new Date(timestamp)
    return isNaN(date.getTime()) ? "" : date.toLocaleDateString()
  }
  function submitQuestion() {
    if (questionInput.inputMethodComposing || featureState.busy) return false
    const accepted = featureState.submit(questionInput.text)
    if (accepted) focusInput()
    return accepted
  }
  function newQuestion() {
    if (!featureState.clear()) return false
    historyVisible = false
    questionInput.clear()
    resetAnswer()
    flushAnswer()
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
    if (historyVisible) return
    if (!featureState.busy) flushAnswer()
    else if (!renderTimer.running) renderTimer.start()
  }
  function flushAnswer() {
    renderTimer.stop()
    if (renderedAnswer === displayedAnswer) return
    const previousY = answerViewport.contentY
    const follow = (!historyVisible || renderedAnswer.length > 0) && answerViewport.contentHeight - answerViewport.height - previousY <= 24
    const revision = ++_renderRevision
    renderedAnswer = displayedAnswer
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
  Shortcut {
    sequence: "Ctrl+H"
    context: Qt.WindowShortcut
    enabled: root.visible
    onActivated: root.toggleHistory()
  }
  Timer { id: renderTimer; interval: 50; onTriggered: root.flushAnswer() }
  Connections {
    target: root.featureState
    function onAnswerChanged() { root.queueAnswer() }
    function onPhaseChanged() {
      if (root.historyVisible) return
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
    property string glyph: ""
    readonly property color ink: !enabled ? Shared.Theme.muted : primary ? Shared.Theme.block : Shared.Theme.foreground
    implicitHeight: 36
    leftPadding: 14
    rightPadding: 14
    focusPolicy: Qt.StrongFocus
    contentItem: Row {
      spacing: 8
      Text {
        visible: control.glyph.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: control.glyph
        color: control.ink
        font { family: Shared.Theme.fontFamily; pixelSize: 14 }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: control.ink
        font { family: Shared.Theme.fontFamily; pixelSize: 13 }
      }
    }
    background: Rectangle {
      radius: 8
      color: control.down ? Shared.Theme.pressed
        : control.hovered ? Shared.Theme.hover
        : control.primary && control.enabled ? Shared.Theme.blue : Shared.Theme.surface
      border.color: control.visualFocus ? Shared.Theme.blue : Shared.Theme.hover
    }
  }

  component IconTile: Rectangle {
    property int tile: 40
    property int glyph: 20
    implicitWidth: tile
    implicitHeight: tile
    radius: tile / 4
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Shared.Theme.blue }
      GradientStop { position: 1; color: Shared.Theme.purple }
    }
    Text {
      anchors.centerIn: parent
      text: "\u2726"
      color: Shared.Theme.block
      font { family: Shared.Theme.fontFamily; pixelSize: parent.glyph }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Shared.Theme.block
    border.color: Shared.Theme.hover
    ColumnLayout {
      anchors { fill: parent; margins: 24 }
      spacing: 14
      RowLayout {
        Layout.fillWidth: true
        spacing: 14
        IconTile {}
        ColumnLayout {
          spacing: 2
          Layout.fillWidth: true
          Text {
            text: "Ask OMP"
            color: Shared.Theme.foreground
            font { family: Shared.Theme.fontFamily; pixelSize: 20; bold: true }
          }
          Text {
            text: "Web only  \u2022  History saved"
            color: Shared.Theme.placeholder
            font { family: Shared.Theme.fontFamily; pixelSize: 12 }
          }
        }
        PanelButton { glyph: "\uf00d"; text: "Close"; onClicked: root.closeRequested() }
        PanelButton {
          objectName: "historyToggle"
          glyph: "\uf1da"
          text: root.historyVisible ? "Current answer" : "History"
          ToolTip.visible: hovered
          ToolTip.text: "Toggle saved history (Ctrl+H)"
          onClicked: root.toggleHistory()
        }
      }
      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Shared.Theme.surface }
      ColumnLayout {
        visible: root.historyVisible
        Layout.fillWidth: true
        spacing: 8
        TextField {
          id: historySearchInput
          objectName: "historySearch"
          Layout.fillWidth: true
          implicitHeight: 40
          placeholderText: "Search saved questions and answers…"
          placeholderTextColor: Shared.Theme.placeholder
          text: root.history.query
          onTextChanged: if (root.history.query !== text) root.history.query = text
          color: Shared.Theme.foreground
          selectionColor: Shared.Theme.blue
          selectedTextColor: Shared.Theme.block
          font { family: Shared.Theme.fontFamily; pixelSize: 14 }
          leftPadding: 12
          Accessible.name: "Search history"
          background: Rectangle {
            radius: 8
            color: Shared.Theme.inputBackground
            border.color: historySearchInput.activeFocus ? Shared.Theme.blue : Shared.Theme.hover
          }
          Keys.onDownPressed: event => { root.moveHistorySelection(1); event.accepted = true }
          Keys.onUpPressed: event => { root.moveHistorySelection(-1); event.accepted = true }
          Keys.onReturnPressed: event => { if (!inputMethodComposing) root.chooseHistoryResult(); event.accepted = true }
          Keys.onEnterPressed: event => { if (!inputMethodComposing) root.chooseHistoryResult(); event.accepted = true }
        }
        Text {
          Layout.fillWidth: true
          text: root.historyMessage || root.history.results.length + (root.history.results.length === 1 ? " conversation · Newest first" : " conversations · Newest first")
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: root.history.error ? Shared.Theme.pink : Shared.Theme.placeholder
          font { family: Shared.Theme.fontFamily; pixelSize: 12 }
        }
        ListView {
          id: historyResults
          objectName: "historyResults"
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(128, contentHeight)
          Layout.maximumHeight: 128
          clip: true
          model: root.history.results
          currentIndex: count > 0 ? 0 : -1
          onModelChanged: currentIndex = count > 0 ? 0 : -1
          boundsBehavior: Flickable.StopAtBounds
          activeFocusOnTab: count > 0
          keyNavigationEnabled: true
          Keys.onReturnPressed: event => { root.chooseHistoryResult(); event.accepted = true }
          Keys.onEnterPressed: event => { root.chooseHistoryResult(); event.accepted = true }
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          delegate: ItemDelegate {
            id: historyRow
            required property var modelData
            required property int index
            width: historyResults.width
            height: 42
            highlighted: ListView.isCurrentItem
            onClicked: {
              historyResults.currentIndex = index
              root.selectHistory(modelData)
            }
            contentItem: RowLayout {
              spacing: 10
              Text {
                Layout.fillWidth: true
                text: historyRow.modelData.question
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Shared.Theme.foreground
                font { family: Shared.Theme.fontFamily; pixelSize: 13 }
              }
              Text {
                text: root.historyDate(historyRow.modelData.timestamp)
                textFormat: Text.PlainText
                color: Shared.Theme.placeholder
                font { family: Shared.Theme.fontFamily; pixelSize: 11 }
              }
            }
            background: Rectangle {
              radius: 6
              color: historyRow.highlighted || historyRow.hovered ? Shared.Theme.hover : "transparent"
              border.color: historyRow.activeFocus ? Shared.Theme.blue : "transparent"
            }
            Accessible.name: modelData.question + ", " + root.historyDate(modelData.timestamp)
          }
        }
      }
      Item {
        Layout.fillWidth: true
        visible: !root.historyVisible
        Layout.preferredHeight: Math.min(132, Math.max(84, questionInput.implicitHeight))
        Layout.minimumHeight: 48
        ScrollView {
          id: inputViewport
          anchors.fill: parent
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
            padding: 14
            rightPadding: 56
            font { family: Shared.Theme.fontFamily; pixelSize: 15 }
            Accessible.name: "Question"
            background: Rectangle {
              radius: 10
              color: Shared.Theme.inputBackground
              border.color: questionInput.activeFocus ? Shared.Theme.blue : Shared.Theme.hover
              border.width: questionInput.activeFocus ? 2 : 1
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
        Rectangle {
          anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
          width: 36
          height: 28
          radius: 7
          opacity: askButton.enabled ? 1 : 0.4
          color: sendArea.pressed ? Shared.Theme.pressed : Shared.Theme.surface
          border.color: Shared.Theme.hover
          Accessible.name: "Send question"
          Text {
            anchors.centerIn: parent
            text: "\uf1d8"
            color: Shared.Theme.blue
            font { family: Shared.Theme.fontFamily; pixelSize: 14 }
          }
          MouseArea {
            id: sendArea
            anchors.fill: parent
            enabled: askButton.enabled
            onClicked: root.submitQuestion()
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        PanelButton {
          id: askButton
          visible: !root.historyVisible
          glyph: "\u2726"; text: "Ask"; primary: true
          enabled: !root.featureState.busy && questionInput.text.trim().length > 0
          onClicked: root.submitQuestion()
        }
        PanelButton {
          glyph: "\uf04d"; text: "Stop"; visible: !root.historyVisible && root.featureState.busy
          enabled: root.featureState.phase !== "cancelling" && root.featureState.phase !== "closing"
          onClicked: root.featureState.cancel()
        }
        PanelButton { glyph: "\uf067"; text: "New question"; enabled: !root.featureState.busy; onClicked: root.newQuestion() }
        Item { Layout.fillWidth: true }
        PanelButton {
          glyph: "\uf0c5"; text: "Copy answer"; enabled: root.displayedAnswer.length > 0
          // A mouse copy should not steal the question/answer's keyboard focus.
          focusPolicy: Qt.TabFocus
          onClicked: root.copyAnswer()
        }
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120
        radius: 12
        color: root.cardColor
        border.color: Shared.Theme.hover
        ColumnLayout {
          anchors { fill: parent; margins: 18 }
          spacing: 10
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            IconTile { tile: 26; glyph: 14 }
            Text {
              text: "OMP Assistant"
              color: Shared.Theme.foreground
              font { family: Shared.Theme.fontFamily; pixelSize: 14; bold: true }
            }
            Text {
              Layout.fillWidth: true
              visible: text.length > 0
              text: root.historyVisible ? "Saved conversation · Read only" : root.featureState.toolActivity
              textFormat: Text.PlainText
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignRight
              color: Shared.Theme.placeholder
              font { family: Shared.Theme.fontFamily; pixelSize: 12 }
            }
          }
          ScrollView {
            visible: root.historyVisible && root.selectedHistory !== null
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.maximumHeight: 56
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            TextArea {
              objectName: "savedQuestion"
              text: root.selectedHistory ? root.selectedHistory.question : ""
              textFormat: TextEdit.PlainText
              readOnly: true
              selectByMouse: true
              selectByKeyboard: true
              wrapMode: TextEdit.Wrap
              padding: 0
              color: Shared.Theme.foreground
              selectionColor: Shared.Theme.blue
              selectedTextColor: Shared.Theme.block
              font { family: Shared.Theme.fontFamily; pixelSize: 14; bold: true }
              background: null
              Accessible.name: "Saved question"
            }
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
              contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Shared.Theme.pressed }
            }
            TextEdit {
              id: answerText
              objectName: "answerEdit"
              width: Math.max(1, answerViewport.width - 22)
              height: Math.max(answerViewport.height, contentHeight)
              text: root.renderedAnswer ? Markdown.toHtml(root.renderedAnswer, root.markdownStyle) : ""
              textFormat: TextEdit.RichText
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
              visible: !root.renderedAnswer && (root.historyVisible || (!root.featureState.busy && !root.featureState.error && !root.featureState.outcome))
              text: root.historyVisible ? (root.selectedHistory ? "No visible assistant answer in this conversation." : "Choose a saved conversation to read it here.") : "Ask a question. Read the answer here."
              wrapMode: Text.Wrap
              color: Shared.Theme.placeholder
              font { family: Shared.Theme.fontFamily; pixelSize: 15 }
            }
          }
          Text {
            Layout.fillWidth: true
            Layout.maximumHeight: 80
            visible: text.length > 0
            text: root.historyVisible ? "" : root.featureState.error
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            color: Shared.Theme.pink
            font { family: Shared.Theme.fontFamily; pixelSize: 12 }
          }
          Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Shared.Theme.hover }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              visible: root.footerGlyph.length > 0
              text: root.footerGlyph
              color: root.footerColor
              font { family: Shared.Theme.fontFamily; pixelSize: 14 }
            }
            Text {
              visible: text.length > 0
              text: root.statusText || root.outcomeText
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: root.footerColor
              font { family: Shared.Theme.fontFamily; pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.historyVisible ? "↑ / ↓ to browse  ·  Enter to read  ·  Ctrl+H to return  ·  Esc to close" : "Enter to ask  ·  Shift+Enter for a new line  ·  Ctrl+H for history  ·  Esc to close"
              color: Shared.Theme.placeholder
              font { family: Shared.Theme.fontFamily; pixelSize: 12 }
            }
          }
        }
      }
    }
  }
}
