import QtQuick
import "../../shared" as Shared
QtObject {
  property var launchRunner: Shared.CommandRunner {}
  function launch() { return launchRunner.launchDetached(["hyprctl", "dispatch", "exec", "foot"]) }
}
