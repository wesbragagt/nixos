import QtQuick
import "../../shared" as Shared
QtObject {
  property var launchRunner: Shared.CommandRunner {}
  function lock() { return launchRunner.launchDetached(["loginctl", "lock-session"]) }
}
