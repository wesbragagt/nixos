import QtQuick
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property var identityRunner: Shared.CommandRunner {}
  property bool identityRequested: false
  property int cpu: -1
  property int memory: -1
  property int disk: -1
  property string cpuModel: ""
  property int logicalCpus: 0
  property string cpuLoad: ""
  property double memoryTotal: -1
  property double memoryAvailable: -1
  property double diskTotal: -1
  property double diskUsed: -1
  property double diskAvailable: -1
  property double previousTotal: 0
  property double previousIdle: 0
  function formatSize(kib) {
    if (kib < 0) return "unavailable"
    return kib >= 1048576 ? (kib / 1048576).toFixed(1) + " GiB" : (kib / 1024).toFixed(1) + " MiB"
  }
  function refresh() {
    if (!identityRequested) identityRequested = identityRunner.start(["cat", "/proc/cpuinfo"])
    return statusRunner.start(["sh", "-c", `
      read tag user nice system idle iowait irq softirq steal rest < /proc/stat
      printf '%s %s\\n' "$((user+nice+system+idle+iowait+irq+softirq+steal))" "$((idle+iowait))"
      cat /proc/meminfo
      df -Pk / | tail -n 1
      read load1 load5 load15 rest < /proc/loadavg
      printf 'LOAD %s %s %s\\n' "$load1" "$load5" "$load15"
    `], "", { LC_ALL: "C" })
  }
  Connections {
    target: state.identityRunner
    function onCompleted(result) {
      const model = result.stdout.match(/^(?:model name|Hardware)\s*:\s*(.+)$/m)
      state.cpuModel = model ? model[1].trim() : ""
      const processors = result.stdout.match(/^processor\s*:/gm)
      state.logicalCpus = processors ? processors.length : 0
    }
  }
  Connections {
    target: state.statusRunner
    function onCompleted(result) {
      const text = result.stdout
      const ticks = text.split("\n")[0].trim().split(/\s+/).map(Number)
      const elapsed = ticks[0] - state.previousTotal
      state.cpu = state.previousTotal > 0 && elapsed > 0
        ? Math.max(0, Math.min(100, Math.round(100 * (1 - (ticks[1] - state.previousIdle) / elapsed)))) : -1
      state.previousTotal = ticks[0]
      state.previousIdle = ticks[1]
      const load = text.match(/^LOAD ([\d.]+) ([\d.]+) ([\d.]+)$/m)
      state.cpuLoad = load ? load.slice(1).join(" / ") : ""
      const total = text.match(/MemTotal:\s+(\d+)/)
      const available = text.match(/MemAvailable:\s+(\d+)/)
      const memoryReady = total && available && Number(total[1]) > 0
      state.memoryTotal = memoryReady ? Number(total[1]) : -1
      state.memoryAvailable = memoryReady ? Number(available[1]) : -1
      state.memory = memoryReady ? Math.round(100 * (1 - state.memoryAvailable / state.memoryTotal)) : -1
      const disk = text.match(/^\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+\/$/m)
      state.diskTotal = disk ? Number(disk[1]) : -1
      state.diskUsed = disk ? Number(disk[2]) : -1
      state.diskAvailable = disk ? Number(disk[3]) : -1
      state.disk = disk ? Number(disk[4]) : -1
    }
  }
  Timer { interval: 2000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
