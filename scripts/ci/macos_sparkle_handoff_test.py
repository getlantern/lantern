"""Exercise the native updater driver in the smoke runner's desktop session."""

import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest


class SparkleHandoffTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if (
            os.environ.get("GITHUB_ACTIONS") != "true"
            or os.environ.get("RUNNER_ENVIRONMENT") != "self-hosted"
        ):
            raise RuntimeError("Run this UI fixture only on the self-hosted CI runner")
        directory = tempfile.TemporaryDirectory(prefix="lantern-updater-driver-")
        cls.addClassCleanup(directory.cleanup)
        cls.driver = Path(directory.name) / "handoff"
        cls.fixture = Path(directory.name) / "fixture"
        for source, binary in (
            (".github/scripts/macos_sparkle_handoff.swift", cls.driver),
            ("scripts/ci/fixtures/macos_sparkle_handoff.swift", cls.fixture),
        ):
            subprocess.run(
                ["xcrun", "swiftc", "-warnings-as-errors", source, "-o", binary],
                check=True,
                timeout=60,
            )
        subprocess.run([cls.driver, "check-access"], check=True, timeout=10)

    def launch(self, mode):
        process = subprocess.Popen([self.fixture, mode])
        threading.Thread(target=process.wait, daemon=True).start()

        def cleanup():
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)

        self.addCleanup(cleanup)
        return process

    def drive(self, action, process, seconds=10):
        return subprocess.run(
            [self.driver, action, str(process.pid), str(seconds)],
            capture_output=True,
            text=True,
            timeout=seconds + 5,
        )

    def test_install_buttons_and_process_exit(self):
        process = self.launch("install")
        prompt = self.drive("wait-prompt", process)
        self.assertEqual(prompt.returncode, 0, prompt.stderr)
        self.assertEqual(prompt.stdout.strip(), "Install Update")
        installed = self.drive("install-until-exit", process)
        self.assertEqual(installed.returncode, 0, installed.stderr)
        self.assertIn("pressed Sparkle Install Update", installed.stdout)
        self.assertIn("pressed Sparkle Install and Relaunch", installed.stdout)
        self.assertEqual(process.wait(timeout=5), 0)

    def test_disabled_and_unrelated_buttons_are_not_pressed(self):
        process = self.launch("disabled")
        window = self.drive("wait-main", process)
        self.assertEqual(window.returncode, 0, window.stderr)
        result = self.drive("install-until-exit", process, seconds=2)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Timed out", result.stderr)
        self.assertIsNone(process.poll())

    def test_process_without_window_does_not_count_as_relaunch(self):
        process = self.launch("no-window")
        result = self.drive("wait-main", process, seconds=3)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Timed out", result.stderr)


if __name__ == "__main__":
    unittest.main()
