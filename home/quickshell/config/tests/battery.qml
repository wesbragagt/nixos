import QtQuick
import Quickshell
import "../features/battery" as Battery
import "../shared" as Shared

ShellRoot {
  FakeRunner { id: status }
  Battery.State { id: battery; pollingEnabled: false; statusRunner: status }
  FloatingWindow {
    visible: true
    implicitWidth: 200
    implicitHeight: 32
    Battery.Widget { id: badge; featureState: battery }
  }
  TestHarness {
    id: t
    steps: [
      () => {
        battery.refresh()
        status.finish("POWER_SUPPLY_NAME=BAT1\nPOWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Discharging\n")
        t.equal(badge.value, "44%", "BAT1 charge is displayed")
        t.verify(badge.visible, "present battery is visible")
        const dischargeIcon = badge.icon
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Charging\n")
        t.verify(badge.icon !== dischargeIcon, "charging changes the battery icon")
        t.equal(badge.accent, Shared.Theme.green, "charging uses green")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=15\nPOWER_SUPPLY_STATUS=Discharging\n")
        t.equal(badge.accent, Shared.Theme.pink, "critical battery uses warning color")
        battery.refresh()
        status.finish("")
        t.verify(!badge.visible, "battery removal clears the old reading")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=101\nPOWER_SUPPLY_STATUS=Unknown\n")
        t.verify(!badge.visible, "invalid capacity is not displayed")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=0\nPOWER_SUPPLY_STATUS=Discharging\n")
        t.verify(badge.visible, "empty battery remains visible")
        t.equal(badge.value, "0%", "zero charge is not treated as absent")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=50\n", "read failed", 1)
        t.verify(!badge.visible, "failed collection does not show a stale charge")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Discharging\nPOWER_SUPPLY_CHARGE_NOW=1500000\nPOWER_SUPPLY_CURRENT_NOW=600000\n")
        t.equal(badge.tooltipText, "Discharging\nAbout 2h 30m remaining", "charge and current estimate remaining runtime")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Discharging\nPOWER_SUPPLY_ENERGY_NOW=18000000\nPOWER_SUPPLY_POWER_NOW=24000000\n")
        t.equal(badge.tooltipText, "Discharging\nAbout 45m remaining", "energy and power estimate remaining runtime")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Discharging\nPOWER_SUPPLY_CHARGE_NOW=1500000\nPOWER_SUPPLY_CURRENT_NOW=0\n")
        t.equal(battery.remainingMinutes, -1, "zero discharge rate clears the estimate")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Charging\nPOWER_SUPPLY_CHARGE_NOW=1500000\nPOWER_SUPPLY_CURRENT_NOW=600000\n")
        t.equal(battery.remainingMinutes, -1, "charging never shows time until empty")
        battery.refresh()
        status.finish("POWER_SUPPLY_CAPACITY=44\nPOWER_SUPPLY_STATUS=Discharging\n")
        t.equal(battery.remainingMinutes, -1, "missing discharge data clears the estimate")
      }
    ]
  }
}
