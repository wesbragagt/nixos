import QtQuick
import "../../shared" as Shared
Item {
  id: state
  property bool pollingEnabled: true
  property var statusRunner: Shared.CommandRunner {}
  property var mutationRunner: Shared.CommandRunner {}
  property var launchRunner: Shared.CommandRunner {}
  property int volume: 0
  property bool muted: false
  function refresh() { return statusRunner.start(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]) }
  function openMixer() { return launchRunner.launchDetached(["pavucontrol", "--tab=1"]) }
  function toggleMute() { return mutationRunner.launchDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]) }
  function adjustVolume(delta) { return mutationRunner.launchDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", delta > 0 ? "5%+" : "5%-"]) }
  Connections {
    target: state.statusRunner
    function onCompleted(result) {
      const audio = result.stdout.match(/Volume:\s+([\d.]+)([^\n]*)/)
      if (audio) {
        state.volume = Math.round(Number(audio[1]) * 100)
        state.muted = audio[2].includes("MUTED")
      }
    }
  }
  Timer { interval: 2000; running: state.pollingEnabled; repeat: true; onTriggered: state.refresh() }
  Component.onCompleted: if (pollingEnabled) refresh()
}
