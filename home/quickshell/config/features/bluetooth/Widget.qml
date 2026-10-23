import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  icon: "\uf293"
  accent: featureState.powered ? Shared.Theme.blue : Shared.Theme.muted
}
