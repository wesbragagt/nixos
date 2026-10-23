import QtQuick
import Quickshell
import "../features/launcher" as Launcher
import "../features/system-metrics" as Metrics
import "../features/workspaces" as Workspaces
import "../features/audio" as Audio
import "../features/idle" as Idle
import "../features/transcription" as Transcription
import "../features/network" as Network
import "../features/bluetooth" as Bluetooth
import "../features/clock" as Clock
import "../features/lock" as Lock

ShellRoot {
  id: root
  property var first: null
  property var second: null
  property double startedAt: Date.now()
  property int sample: 0
  property var counts: []
  FakeRunner { id: stats; onStarted: { root.sample++; finish((1000 + root.sample * 200) + " " + (700 + root.sample * 50) + "\n") } }
  FakeRunner { id: identity; onStarted: finish("model name : Lifetime CPU\nprocessor : 0\n") }
  FakeRunner { id: audioStatus; onStarted: finish("Volume: 0.42") }
  FakeRunner { id: idleStatus; onStarted: finish('{"class":"enabled"}') }
  FakeRunner { id: transStatus; onStarted: finish('{"class":"enabled"}') }
  FakeRunner { id: bluetoothStatus; onStarted: finish("Powered: yes") }
  FakeRunner { id: networkStatus; onStarted: finish("ethernet:connected") }
  FakeRunner { id: unused }
  Launcher.State { id: launcher; launchRunner: unused }
  Metrics.State { id: metrics; statusRunner: stats; identityRunner: identity }
  Audio.State { id: audio; statusRunner: audioStatus; mutationRunner: unused; launchRunner: unused }
  Idle.State { id: idle; statusRunner: idleStatus; mutationRunner: unused }
  Transcription.State { id: transcription; featureEnabled: true; statusRunner: transStatus; mutationRunner: unused }
  Bluetooth.State { id: bluetooth; statusRunner: bluetoothStatus }
  Network.NetworkState { id: network; statusRunner: networkStatus; scanRunner: unused; connectRunner: unused; radioRunner: unused; settingsRunner: unused }
  QtObject { id: workspaceSource; property var workspaces: []; property var focusedWorkspace: null; function activate(workspace) {} }
  Workspaces.State { id: workspaces; source: workspaceSource }
  QtObject { id: clockSource; property date date: new Date(2026, 9, 21, 9, 3) }
  Clock.State { id: clock; source: clockSource }
  Lock.State { id: lock; launchRunner: unused }
  Component {
    id: layout
    // PanelWindow has no offscreen backend: exercise the complete feature widget
    // set in disposable windows; the managed Wayland shell proves the real layout.
    FloatingWindow {
      id: host
      visible: false
      implicitWidth: 2560
      implicitHeight: 32
      Row {
        Launcher.Widget { featureState: launcher }
        Metrics.Widget { featureState: metrics }
        Workspaces.Widget { featureState: workspaces }
        Audio.Widget { featureState: audio }
        Idle.Widget { featureState: idle }
        Transcription.Widget { featureState: transcription }
        Network.NetworkWidget { networkState: network; popupHostWindow: host }
        Bluetooth.Widget { featureState: bluetooth }
        Clock.Widget { featureState: clock }
        Lock.Widget { featureState: lock }
      }
    }
  }
  function pollCounts() {
    return [stats, audioStatus, idleStatus, transStatus, bluetoothStatus, networkStatus].map(r => r.calls.length)
  }
  Component.onCompleted: {
    first = layout.createObject(root)
    second = layout.createObject(root)
  }
  TestHarness {
    id: t
    steps: [
      () => {
        if (Date.now() - root.startedAt < 2200) return false
        t.verify(root.first !== null && root.second !== null, "two complete feature widget sets construct")
        root.pollCounts().forEach(count => t.equal(count, 2, "one initial collection and one shared cadence for each polling domain"))
        t.equal(metrics.cpu, 75, "shared CPU baseline advances between timer samples")
        t.equal(identity.calls.length, 1, "two layouts collect hardware identity once")
        root.first.destroy()
        root.first = null
        root.second.destroy()
        root.second = null
        root.startedAt = Date.now()
      },
      () => {
        if (Date.now() - root.startedAt < 2100) return false
        root.pollCounts().forEach(count => t.equal(count, 3, "polling survives destruction of every layout"))
        t.equal(metrics.cpu, 75, "CPU baseline survives destruction of every layout")
        t.equal(network.popupCount, 0, "closed layout popups retain no scan demand")
        root.counts = root.pollCounts()
        root.first = layout.createObject(root)
        root.second = layout.createObject(root)
        root.startedAt = Date.now()
      },
      () => {
        if (Date.now() - root.startedAt < 50) return false
        root.pollCounts().forEach((count, i) => t.equal(count, root.counts[i], "layout recreation does not restart a collector"))
        t.equal(metrics.cpu, 75, "layout recreation retains CPU history")
        t.equal(identity.calls.length, 1, "layout recreation does not recollect identity")
        t.equal(unused.calls.length + unused.detachedCalls.length, 0, "layout lifetime never launches actions or scans")
      }
    ]
  }
}
