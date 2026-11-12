import QtQuick
QtObject {
  property var source: NativeSource {}
  readonly property string text: Qt.formatDateTime(source.date, "MMM d · h:mmap")
}
