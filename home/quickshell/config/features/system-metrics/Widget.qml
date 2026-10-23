import QtQuick
import "../../shared" as Shared
Row {
  required property var featureState
  spacing: 20
  Shared.Badge {
    icon: "\uf4bc"
    value: featureState.cpu < 0 ? "N/A" : featureState.cpu + "%"
    accent: Shared.Theme.pink
    tooltipText: "CPU usage: " + (featureState.cpu < 0 ? "waiting for samples" : featureState.cpu + "%")
      + "\nModel: " + (featureState.cpuModel || "unavailable")
      + "\nLogical CPUs: " + (featureState.logicalCpus || "unavailable")
      + "\nLoad (1 / 5 / 15 min): " + (featureState.cpuLoad || "unavailable")
  }
  Shared.Badge {
    icon: "\uefc5"
    value: featureState.memory < 0 ? "N/A" : featureState.memory + "%"
    accent: Shared.Theme.purple
    tooltipText: "Memory: " + (featureState.memory < 0 ? "unavailable" : featureState.memory + "% used")
      + "\nUsed: " + featureState.formatSize(featureState.memoryTotal < 0 ? -1 : featureState.memoryTotal - featureState.memoryAvailable)
      + "\nAvailable: " + featureState.formatSize(featureState.memoryAvailable)
      + "\nTotal: " + featureState.formatSize(featureState.memoryTotal)
  }
  Shared.Badge {
    icon: "\uf0a0"
    value: featureState.disk < 0 ? "N/A" : featureState.disk + "%"
    accent: Shared.Theme.yellow
    tooltipText: "Root filesystem (/): " + (featureState.disk < 0 ? "unavailable" : featureState.disk + "% used")
      + "\nUsed: " + featureState.formatSize(featureState.diskUsed)
      + "\nAvailable: " + featureState.formatSize(featureState.diskAvailable)
      + "\nTotal: " + featureState.formatSize(featureState.diskTotal)
  }
}
