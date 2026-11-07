import QtQuick
import "../../shared" as Shared

Shared.Badge {
  required property var featureState
  visible: featureState.available
  icon: featureState.charging ? "\uf0e7" : featureState.capacity <= 15 ? "\uf244" : featureState.capacity <= 35 ? "\uf243" : featureState.capacity <= 65 ? "\uf242" : featureState.capacity <= 85 ? "\uf241" : "\uf240"
  value: featureState.capacity + "%"
  tooltipText: featureState.tooltipText
  accent: featureState.charging || featureState.status === "Full" ? Shared.Theme.green : featureState.capacity <= 15 ? Shared.Theme.pink : featureState.capacity <= 30 ? Shared.Theme.yellow : Shared.Theme.blue
}
