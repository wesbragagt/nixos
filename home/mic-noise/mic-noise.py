#!/usr/bin/env python3
"""Local streaming processor. Audio is never written to disk."""
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import tempfile
import urllib.request

MODEL_URL = "https://raw.githubusercontent.com/richardpl/arnndn-models/0fda24c46d78f0207d820bb970fbe85c1971b39c/bd.rnnn"
MODEL_HASH = "ae3f7411e1e6a884f839a4a145c394408398f09854dbc1216ee02faafc98a17b"
PRESETS = {"Light": 0.5, "Balanced": 0.75, "Strong": 1.0}
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "mic-noise"
STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "mic-noise"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "mic-noise"


def pactl(*args):
    result = subprocess.run(["pactl", *args], capture_output=True, text=True, check=True, timeout=10)
    return result.stdout.strip()


def model():
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / "bd.rnnn"
    if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == MODEL_HASH:
        return path
    # Upstream weights have no explicit license. Download is user-authorized,
    # pinned independently of any Nix build and reused offline after verification.
    with urllib.request.urlopen(MODEL_URL, timeout=30) as response:
        data = response.read(1024 * 1024)
    if hashlib.sha256(data).hexdigest() != MODEL_HASH:
        raise RuntimeError("Downloaded model checksum mismatch")
    with tempfile.NamedTemporaryFile(dir=CACHE, delete=False) as output:
        output.write(data)
        temporary = Path(output.name)
    temporary.replace(path)
    return path


class Processor:
    def __init__(self):
        self.settings = {"enabled": False, "preset": "Balanced"}
        settings = STATE / "settings.json"
        self.settings_error = ""
        try:
            if settings.exists():
                saved = json.loads(settings.read_text())
                if not isinstance(saved, dict) or type(saved.get("enabled")) is not bool or saved.get("preset") not in PRESETS:
                    raise ValueError("Invalid microphone settings")
                self.settings = {"enabled": saved["enabled"], "preset": saved["preset"]}
        except (OSError, ValueError) as exc:
            self.settings_error = f"Cannot load microphone settings: {exc}"
        self.status = "starting"
        self.error = ""
        self.source = ""
        self.modules = []
        self.child = None
        self.model_path = None
        self.stopping = False

    def snapshot(self):
        return dict(self.settings, status=self.status, error=self.error, source=self.source)

    def save(self):
        STATE.mkdir(parents=True, exist_ok=True)
        temporary = STATE / "settings.tmp"
        temporary.write_text(json.dumps(self.settings))
        temporary.replace(STATE / "settings.json")

    def stop_child(self):
        if self.child is not None:
            if self.child.poll() is None:
                self.child.terminate()
                try:
                    self.child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.child.kill()
                    self.child.wait()
            self.child = None

    def physical_source(self):
        sources = json.loads(pactl("--format=json", "list", "sources"))
        names = [s["name"] for s in sources if s["name"] != "mic_noise" and not s["name"].endswith(".monitor") and not s.get("monitor_source") and s.get("properties", {}).get("device.class") != "monitor"]
        default = pactl("get-default-source")
        if default in names:
            return default
        if default == "mic_noise" and self.source in names:
            return self.source
        raise RuntimeError("No physical default microphone available")

    def start(self):
        self.stop_child()
        self.status = "starting"
        self.error = ""
        if self.settings_error:
            self.status = "failed"
            self.error = self.settings_error
            self.settings_error = ""
            return
        try:
            self.source = self.physical_source()
            if self.model_path is None:
                self.model_path = model()
            if not self.modules:
                self.modules.append(pactl("load-module", "module-null-sink", "sink_name=mic_noise_sink", "rate=48000", "channels=1", "channel_map=mono", "sink_properties=device.description=MicrophoneProcessing"))
            if len(self.modules) == 1:
                self.modules.append(pactl("load-module", "module-remap-source", "master=mic_noise_sink.monitor", "source_name=mic_noise", "source_properties=device.description=CleanMicrophone"))
            mix = PRESETS[self.settings["preset"]]
            # A filter path without user-controlled delimiters avoids filtergraph escaping.
            graph = f"arnndn=m=bd.rnnn:mix={mix}:enable={int(self.settings['enabled'])}"
            self.child = subprocess.Popen([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin",
                "-f", "pulse", "-fragment_size", "1920", "-i", self.source,
                "-ac", "1", "-ar", "48000", "-af", graph,
                "-f", "pulse", "-device", "mic_noise_sink", "Clean Microphone",
            ], cwd=CACHE, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                env=dict(os.environ, PULSE_SINK="mic_noise_sink"))
            try:
                code = self.child.wait(timeout=0.25)
            except subprocess.TimeoutExpired:
                self.status = "running"
            else:
                raise RuntimeError(f"FFmpeg failed to start ({code}); inspect journalctl --user -u mic-noise")
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
            self.status = "failed"
            self.error = str(exc)

    def tick(self):
        if self.status != "running":
            return
        if self.child.poll() is not None:
            self.status = "failed"
            self.error = f"FFmpeg exited ({self.child.returncode}); inspect journalctl --user -u mic-noise"
            return
        try:
            if self.physical_source() != self.source:
                self.start()
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
            self.stop_child()
            self.status = "failed"
            self.error = str(exc)

    def command(self, command):
        args = command.split()
        if args == ["status"]:
            return self.snapshot()
        if args == ["restart"]:
            self.start()
        elif args == ["toggle"] or (len(args) == 2 and args[0] == "preset" and args[1] in PRESETS):
            if self.status != "running":
                return dict(self.snapshot(), commandError="Restart the failed processor first")
            previous = self.settings.copy()
            if args[0] == "toggle":
                self.settings["enabled"] = not self.settings["enabled"]
            else:
                self.settings["preset"] = args[1]
            try:
                self.save()
            except OSError as exc:
                self.settings = previous
                return dict(self.snapshot(), commandError=f"Cannot save microphone settings: {exc}")
            self.start()
        else:
            return dict(self.snapshot(), commandError="Invalid microphone command")
        result = self.snapshot()
        if self.status == "failed":
            result["commandError"] = self.error
        return result

    def close(self):
        self.stop_child()
        for module in reversed(self.modules):
            try:
                pactl("unload-module", module)
            except (OSError, subprocess.SubprocessError):
                pass


def daemon():
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    # flock prevents concurrent daemons without deleting a live instance's socket.
    import fcntl
    with (RUNTIME / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        endpoint = RUNTIME / "control.sock"
        endpoint.unlink(missing_ok=True)
        processor = Processor()
        signal.signal(signal.SIGTERM, lambda *_: setattr(processor, "stopping", True))
        signal.signal(signal.SIGINT, lambda *_: setattr(processor, "stopping", True))
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(endpoint))
            server.listen(4)
            try:
                processor.start()
                while not processor.stopping:
                    if select.select([server], [], [], 1)[0]:
                        with server.accept()[0] as connection:
                            connection.settimeout(2)
                            try:
                                command = connection.recv(1024).decode()
                                response = processor.command(command)
                                connection.sendall(json.dumps(response).encode())
                            except (OSError, UnicodeError) as exc:
                                print(str(exc), file=sys.stderr)
                    processor.tick()
            finally:
                processor.close()
                endpoint.unlink(missing_ok=True)


def main():
    if sys.argv[1:] == ["daemon"]:
        daemon()
        return
    try:
        with socket.socket(socket.AF_UNIX) as client:
            client.settimeout(90)
            client.connect(str(RUNTIME / "control.sock"))
            client.sendall(" ".join(sys.argv[1:] or ["status"]).encode())
            data = b""
            while block := client.recv(4096):
                data += block
        response = json.loads(data)
    except (OSError, ValueError) as exc:
        response = {"status": "unavailable", "enabled": False, "preset": "Balanced", "source": "", "error": f"Microphone service unavailable: {exc}"}
    print(json.dumps(response))
    if response.get("commandError") or response["status"] == "unavailable":
        sys.exit(1)


if __name__ == "__main__":
    main()
