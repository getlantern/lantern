from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parent / "upload-testflight.sh"
TIMEOUT = "ERROR: ... Error Domain=NSURLErrorDomain Code=-1001 \"The request timed out.\"\nReceived status -19235."
REDUNDANT = "ERROR: Redundant Binary Upload. You've already uploaded a build with build number '1'."
INVALID = "ERROR: Invalid Provisioning Profile."


class UploadTestflightTest(unittest.TestCase):
    def run_upload(self, *outcomes: tuple[int, str]) -> tuple[subprocess.CompletedProcess[str], int, Path]:
        work = Path(self.enterContext(tempfile.TemporaryDirectory()))
        bin_dir = work / "bin"
        bin_dir.mkdir()
        responses = work / "responses"
        for i, (code, output) in enumerate(outcomes, 1):
            (responses / str(i)).mkdir(parents=True)
            (responses / str(i) / "code").write_text(str(code))
            (responses / str(i) / "output").write_text(output)
        calls = work / "calls"
        xcrun = bin_dir / "xcrun"
        xcrun.write_text(
            "#!/usr/bin/env bash\n"
            f"n=$(( $(cat {calls} 2>/dev/null || echo 0) + 1 )); echo $n > {calls}\n"
            f"[ -f \"$HOME/private_keys/AuthKey_KEYID.p8\" ] || {{ echo missing key; exit 99; }}\n"
            f"cat {responses}/$n/output; exit $(cat {responses}/$n/code)\n"
        )
        xcrun.chmod(0o755)
        home = work / "home"
        home.mkdir()
        env = {
            **os.environ,
            "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
            "HOME": str(home),
            "APPSTORE_API_KEY_ID": "KEYID",
            "APPSTORE_ISSUER_ID": "issuer",
            "APPSTORE_API_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----",
            "UPLOAD_BACKOFF": "1",
        }
        result = subprocess.run(
            ["bash", str(SCRIPT), "app.ipa"], env=env, capture_output=True, text=True, timeout=60,
        )
        count = int(calls.read_text()) if calls.exists() else 0
        return result, count, home

    def test_success_needs_one_attempt_and_removes_the_key(self) -> None:
        result, calls, home = self.run_upload((0, "No errors uploading"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, 1)
        self.assertFalse((home / "private_keys/AuthKey_KEYID.p8").exists())

    def test_transient_failure_is_retried(self) -> None:
        result, calls, _ = self.run_upload((1, TIMEOUT), (0, "No errors uploading"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, 2)

    def test_redundant_upload_after_a_lost_response_succeeds(self) -> None:
        result, calls, _ = self.run_upload((1, TIMEOUT), (1, REDUNDANT))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, 2)

    def test_redundant_upload_on_first_attempt_fails(self) -> None:
        result, calls, _ = self.run_upload((1, REDUNDANT))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls, 1)

    def test_other_errors_fail_without_retry(self) -> None:
        result, calls, _ = self.run_upload((1, INVALID))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls, 1)

    def test_gives_up_after_the_attempt_limit(self) -> None:
        result, calls, home = self.run_upload(*[(1, TIMEOUT)] * 4)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls, 4)
        self.assertIn("giving up after 4 attempts", result.stderr)
        self.assertFalse((home / "private_keys/AuthKey_KEYID.p8").exists())


if __name__ == "__main__":
    unittest.main()
