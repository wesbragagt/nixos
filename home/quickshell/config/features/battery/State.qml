import QtQuick
import "../../shared" as Shared

Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property int capacity: -1
  property string status: ""
  property int remainingMinutes: -1
  readonly property string remainingTime: remainingMinutes < 0 ? "" : remainingMinutes >= 60 ? Math.floor(remainingMinutes / 60) + "h " + (remainingMinutes % 60) + "m" : remainingMinutes + "m"
  readonly property string tooltipText: status + (remainingTime ? "\nAbout " + remainingTime + (charging ? " until full" : " remaining") : "")
  readonly property bool available: capacity >= 0
  readonly property bool charging: status === "Charging"

  function refresh() {
    return statusRunner.start(["sh", "-c", 'for battery in /sys/class/power_supply/*; do [ "$(cat "$battery/type" 2>/dev/null)" = Battery ] || continue; [ "$(cat "$battery/present" 2>/dev/null)" = 0 ] && continue; cat "$battery/uevent"; break; done'])
  }

  Connections {
    target: state.statusRunner
    function onCompleted(result) {
      const capacity = result.stdout.match(/^POWER_SUPPLY_CAPACITY=(\d+)$/m)
      const status = result.stdout.match(/^POWER_SUPPLY_STATUS=(.+)$/m)
      state.capacity = result.exitCode === 0 && capacity && Number(capacity[1]) <= 100 ? Number(capacity[1]) : -1
      state.status = status ? status[1] : ""
      function reading(name) {
        const match = result.stdout.match(new RegExp("^POWER_SUPPLY_" + name + "=(\\d+)$", "m"))
        return match ? Number(match[1]) : NaN
      }
      const energy = reading("ENERGY_NOW")
      const power = reading("POWER_NOW")
      const energyFull = reading("ENERGY_FULL")
      const charge = reading("CHARGE_NOW")
      const current = reading("CURRENT_NOW")
      const chargeFull = reading("CHARGE_FULL")
      const energyLeft = state.charging ? energyFull - energy : energy
      const chargeLeft = state.charging ? chargeFull - charge : charge
      const hours = power > 0 && energyLeft >= 0 ? energyLeft / power : current > 0 && chargeLeft >= 0 ? chargeLeft / current : NaN
      state.remainingMinutes = state.available && (state.charging || state.status === "Discharging") && Number.isFinite(hours) ? Math.round(hours * 60) : -1
    }
  }
  Timer { interval: 30000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
