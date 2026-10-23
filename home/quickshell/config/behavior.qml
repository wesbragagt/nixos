import Quickshell
import QtQuick

// Separate offscreen entrypoint; never loaded by the production shell.
ShellRoot {
  Loader {
    source: "tests/" + Quickshell.env("QUICKSHELL_TEST_SCENARIO") + ".qml"
  }
}
