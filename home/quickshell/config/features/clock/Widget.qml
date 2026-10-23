import QtQuick
import "../../shared" as Shared
Shared.Badge {
  required property var featureState
  icon: "\uf017"
  value: featureState.text
  accent: Shared.Theme.green
}
