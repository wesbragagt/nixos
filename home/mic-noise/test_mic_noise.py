import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mic_noise", Path(__file__).with_name("mic-noise.py"))
mic = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mic)


class ModelIntegrity(unittest.TestCase):
    def test_failed_save_keeps_actual_processing_settings(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(mic, "STATE", Path(directory)):
            processor = mic.Processor()
            processor.status = "running"
            with patch.object(processor, "save", side_effect=OSError("disk full")):
                result = processor.command("toggle")
            self.assertFalse(result["enabled"])
            self.assertIn("disk full", result["commandError"])

    def test_corrupt_settings_expose_recoverable_error(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(mic, "STATE", Path(directory)):
            (Path(directory) / "settings.json").write_text("[]")
            processor = mic.Processor()
            processor.start()
            self.assertEqual(processor.status, "failed")
            self.assertIn("settings", processor.error)
            with patch.object(processor, "physical_source", side_effect=RuntimeError("No physical microphone")):
                result = processor.command("restart")
            self.assertEqual(result["error"], "No physical microphone")

    def test_verified_cache_works_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bd.rnnn"
            path.write_bytes(b"verified fixture")
            with patch.object(mic, "CACHE", Path(directory)), patch.object(mic, "MODEL_HASH", hashlib.sha256(path.read_bytes()).hexdigest()), patch.object(mic.urllib.request, "urlopen", side_effect=AssertionError("offline")):
                self.assertEqual(mic.model(), path)

    def test_corrupt_download_never_replaces_cached_model(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bd.rnnn"
            path.write_bytes(b"corrupt cache")
            import io
            with patch.object(mic, "CACHE", Path(directory)), patch.object(mic.urllib.request, "urlopen", return_value=io.BytesIO(b"corrupt download")):
                with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
                    mic.model()
            self.assertEqual(path.read_bytes(), b"corrupt cache")

    def test_monitor_and_virtual_sources_cannot_feed_processor(self):
        import json
        sources = [{"name": "mic_noise"}, {"name": "desktop.monitor"}, {"name": "other-monitor", "monitor_source": "desktop"}, {"name": "physical"}]
        with tempfile.TemporaryDirectory() as directory, patch.object(mic, "STATE", Path(directory)):
            processor = mic.Processor()
            processor.source = "physical"
            with patch.object(mic, "pactl", side_effect=[json.dumps(sources), "mic_noise"]):
                self.assertEqual(processor.physical_source(), "physical")
            with patch.object(mic, "pactl", side_effect=[json.dumps(sources), "desktop.monitor"]):
                with self.assertRaisesRegex(RuntimeError, "No physical"):
                    processor.physical_source()


if __name__ == "__main__":
    unittest.main()
