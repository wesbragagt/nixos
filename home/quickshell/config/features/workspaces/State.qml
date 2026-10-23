import QtQuick
QtObject {
  property var source: NativeSource {}
  readonly property var workspaces: source.workspaces
  readonly property var focusedWorkspace: source.focusedWorkspace
  function activate(workspace) { source.activate(workspace) }
}
