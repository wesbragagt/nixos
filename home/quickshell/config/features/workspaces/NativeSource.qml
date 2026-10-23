import QtQuick
import Quickshell.Hyprland
QtObject {
  readonly property var workspaces: Hyprland.workspaces
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  function activate(workspace) { workspace.activate() }
}
