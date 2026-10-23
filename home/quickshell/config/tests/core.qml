import QtQuick
import Quickshell
import QtTest
import "../features/launcher" as Launcher
import "../features/system-metrics" as Metrics
import "../features/workspaces" as Workspaces
import "../features/audio" as Audio
import "../features/idle" as Idle
import "../features/transcription" as Transcription
import "../features/bluetooth" as Bluetooth
import "../features/clock" as Clock
import "../features/lock" as Lock
import "../shared" as Shared
ShellRoot {
  property double constructedAt: Date.now()
  TestCase { id: input; name: "ControlledPointer"; when: false }
  FakeRunner { id: stats }
  FakeRunner { id: identity }
  FakeRunner { id: audioStatus }
  FakeRunner { id: audioMutation }
  FakeRunner { id: mixer }
  FakeRunner { id: idleStatus }
  FakeRunner { id: idleMutation }
  FakeRunner { id: transStatus }
  FakeRunner { id: transMutation }
  FakeRunner { id: disabledStatus }
  FakeRunner { id: disabledMutation }
  FakeRunner { id: bluetoothStatus }
  FakeRunner { id: launcherRunner }
  FakeRunner { id: lockRunner }
  Metrics.State { id: metrics; pollingEnabled: false; statusRunner: stats; identityRunner: identity }
  Audio.State { id: audio; pollingEnabled: false; statusRunner: audioStatus; mutationRunner: audioMutation; launchRunner: mixer }
  Idle.State { id: idle; pollingEnabled: false; statusRunner: idleStatus; mutationRunner: idleMutation }
  Transcription.State { id: trans; pollingEnabled: false; featureEnabled: true; statusRunner: transStatus; mutationRunner: transMutation }
  Transcription.State { id: disabled; featureEnabled: false; statusRunner: disabledStatus; mutationRunner: disabledMutation }
  Bluetooth.State { id: bluetooth; pollingEnabled: false; statusRunner: bluetoothStatus }
  Launcher.State { id: launcher; launchRunner: launcherRunner }
  Lock.State { id: lock; launchRunner: lockRunner }
  QtObject { id: firstWorkspace; property string name: "1" }
  QtObject { id: specialWorkspace; property string name: "special" }
  QtObject { id: lastWorkspace; property string name: "9" }
  QtObject {
    id: workspaceSource
    property var workspaces: [firstWorkspace, specialWorkspace, lastWorkspace]
    property var focusedWorkspace: workspaceSource.workspaces[1]
    property var activated: null
    function activate(workspace) { activated = workspace; focusedWorkspace = workspace }
  }
  Workspaces.State { id: workspaces; source: workspaceSource }
  QtObject { id: clockSource; property date date: new Date(2026, 9, 21, 9, 3) }
  Clock.State { id: clock; source: clockSource }
  FloatingWindow {
    visible: true
    implicitWidth: 1600
    implicitHeight: 64
    Row {
      Launcher.Widget { id: launcherWidget; featureState: launcher }
      Metrics.Widget { featureState: metrics }
      Workspaces.Widget { id: workspaceWidget; featureState: workspaces }
      Audio.Widget { id: audioWidget; featureState: audio }
      Audio.Widget { id: otherAudioWidget; featureState: audio }
      Idle.Widget { id: idleWidget; featureState: idle }
      Transcription.Widget { id: transWidget; featureState: trans }
      Transcription.Widget { id: disabledWidget; featureState: disabled }
      Bluetooth.Widget { id: bluetoothWidget; featureState: bluetooth }
      Clock.Widget { id: clockWidget; featureState: clock }
      Lock.Widget { id: lockWidget; featureState: lock }
    }
  }
  function find(item, name) {
    if (item.objectName === name) return item
    for (let child of item.children || []) { const found = find(child, name); if (found) return found }
    return null
  }
  TestHarness {
    id: t
    steps: [
      () => {
        if (Date.now() - constructedAt < 2100) return false
        t.equal(stats.calls.length + identity.calls.length + audioStatus.calls.length + idleStatus.calls.length + transStatus.calls.length + bluetoothStatus.calls.length, 0, "disabled polling prevents initial collection")
        t.verify(!disabled.refresh() && !disabled.toggle(), "disabled transcription refuses explicit commands")
        t.equal(disabledStatus.calls.length + disabledMutation.calls.length, 0, "feature gate starts no commands")
        t.verify(!disabledWidget.visible, "feature gate hides widget")
        metrics.refresh()
        t.verify(!metrics.refresh(), "busy metric collection skipped")
        t.equal(stats.calls.length, 1, "busy refresh does not replace sample")
        identity.finish("processor : 0\nmodel name : Fixture CPU\nprocessor : 1\n")
        stats.finish("1000 700\nMemTotal: 2048000 kB\nMemAvailable: 512000 kB\n/dev/root 10000 4000 6000 40% /\nLOAD 1.2 0.5 0.1\n")
        t.equal(metrics.cpu, -1, "first CPU sample unavailable")
        t.equal(metrics.memory, 75, "memory used percent")
        t.equal(metrics.disk, 40, "root disk percent")
        t.equal(metrics.cpuModel, "Fixture CPU", "CPU identity parsed")
        t.equal(metrics.logicalCpus, 2, "CPU identity processor count")
        t.equal(metrics.cpuLoad, "1.2 / 0.5 / 0.1", "load tooltip detail")
        t.equal(metrics.formatSize(metrics.memoryAvailable), "500.0 MiB", "memory detail unit")
        metrics.refresh()
        stats.finish("1200 750\nMemTotal: 0 kB\n")
        t.equal(metrics.cpu, 75, "known CPU delta")
        t.equal(metrics.memory, -1, "zero total memory unavailable")
        t.equal(metrics.disk, -1, "missing disk unavailable")
        t.equal(metrics.diskAvailable, -1, "missing disk detail unavailable")
        t.equal(metrics.formatSize(metrics.memoryTotal), "unavailable", "missing memory detail unavailable")
        t.equal(identity.calls.length, 1, "hardware identity collected once")
        metrics.refresh(); stats.finish("1200 750\nMemTotal: 1000\n")
        t.equal(metrics.cpu, -1, "no elapsed CPU delta unavailable")
        t.equal(metrics.memory, -1, "missing available memory unavailable")
        audio.refresh(); audioStatus.finish("Volume: 0.42 [MUTED]\n")
        t.equal(audioWidget.value, "mute", "mute renders")
        audio.refresh(); audioStatus.finish("unavailable", "error", 1)
        t.equal(audio.volume, 42, "absent audio retains volume")
        t.verify(audio.muted, "absent audio retains mute")
        audio.refresh(); audioStatus.finish("Volume: 0.55\n")
        t.equal(audioWidget.value, "55%", "audio renders shared update")
        t.equal(otherAudioWidget.value, "55%", "second monitor observes same update")
        input.mouseClick(audioWidget, audioWidget.width / 2, 12, Qt.LeftButton)
        input.mouseClick(audioWidget, audioWidget.width / 2, 12, Qt.RightButton)
        input.mouseWheel(audioWidget, audioWidget.width / 2, 12, 0, 120)
        input.mouseWheel(audioWidget, audioWidget.width / 2, 12, 0, -120)
        t.equal(mixer.detachedCalls[0].argv.join(" "), "pavucontrol --tab=1", "left click opens Playback")
        t.equal(audioMutation.detachedCalls[0].argv.join(" "), "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "right click mutes")
        t.equal(audioMutation.detachedCalls[1].argv.join(" "), "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "wheel up caps volume")
        t.equal(audioMutation.detachedCalls[2].argv.slice(-1)[0], "5%-", "wheel down decreases")
        idle.refresh(); idleStatus.finish('{"class":"disabled"}')
        t.equal(idleWidget.value, "awake", "idle disabled state")
        input.mouseClick(idleWidget, idleWidget.width / 2, 12)
        t.verify(!idle.toggle(), "competing idle toggle skipped")
        idleMutation.finish()
        t.verify(idleStatus.busy, "toggle completion refreshes status")
        idleStatus.finish('{"class":"enabled"}')
        t.equal(idleWidget.value, "idle", "idle refreshed after toggle")
        for (const pair of [["disabled", "off"], ["enabled", "auto"], ["recording", "REC"]]) {
          trans.refresh(); transStatus.finish(JSON.stringify({class:pair[0]}))
          t.equal(transWidget.value, pair[1], "transcription " + pair[0])
        }
        trans.refresh(); transStatus.finish('{"class":"recording"}', "failed", 1)
        t.equal(transWidget.value, "?", "failed transcription becomes unknown")
        input.mouseClick(transWidget, transWidget.width / 2, 12); transMutation.finish()
        t.verify(transStatus.busy, "transcription toggle refresh")
        transStatus.finish('{"class":"disabled"}')
        bluetooth.refresh(); bluetoothStatus.finish("Powered: yes\n")
        t.equal(bluetoothWidget.accent.toString(), Shared.Theme.blue.toString(), "Bluetooth powered style")
        bluetooth.refresh(); bluetoothStatus.finish("")
        t.equal(bluetoothWidget.accent.toString(), Shared.Theme.muted.toString(), "Bluetooth absent style")
        t.equal(clockWidget.value, "Wed, 21 Oct, 09:03 AM", "clock formatting")
        clockSource.date = new Date(2026, 9, 21, 13, 4)
        t.equal(clockWidget.value, "Wed, 21 Oct, 01:04 PM", "injected clock updates")
        input.mouseClick(launcherWidget, launcherWidget.width / 2, 12)
        input.mouseClick(lockWidget, lockWidget.width / 2, 12)
        t.equal(launcherRunner.detachedCalls[0].argv.join(" "), "hyprctl dispatch exec foot", "terminal launch requested safely")
        t.equal(lockRunner.detachedCalls[0].argv.join(" "), "loginctl lock-session", "lock requested only through fake")
      },
      () => {
        const first = find(workspaceWidget, "workspace-1")
        const special = find(workspaceWidget, "workspace-special")
        const last = find(workspaceWidget, "workspace-9")
        if (!first || !special || !last) return false
        t.verify(special.active && !first.active && !last.active, "all workspaces rendered with global focus")
        input.mouseClick(last, last.width / 2, 12)
        t.verify(workspaceSource.activated === workspaceSource.workspaces[2], "workspace click activates selected identity")
        t.verify(last.active && !special.active, "global focus updates highlight")
      }
    ]
  }
}
