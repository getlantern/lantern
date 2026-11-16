from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("verify_android_version.sh")
BASH = shutil.which("bash")


class AndroidVersionVerificationTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.command_log = self.work / "commands.jsonl"
        self.apkanalyzer = self.work / "apkanalyzer"
        self.apkanalyzer.write_text(f"#!{sys.executable}\n" + """
import json, os, sys
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
print(json.loads(os.environ["APK_VERSIONS"]).get(sys.argv[-1], ""))
sys.exit(int(os.environ.get("ANALYZER_EXIT", "0")))
""")
        self.apkanalyzer.chmod(0o755)

    def verify(self, *args: str, versions: dict[str, str] | None = None,
               **env: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [BASH, str(SCRIPT), *args],
            env={
                **os.environ, "PATH": str(self.work),
                "COMMAND_LOG": str(self.command_log),
                "APK_VERSIONS": json.dumps(versions or {}), **env,
            },
            capture_output=True, text=True, timeout=10,
        )

    def test_full_version_matches_both_apks(self) -> None:
        for version in ("10.0.3", "10.0.3-beta-10", "10.0.3-beta-10+build.123",
                        "10.0.3-nightly-20261020"):
            with self.subTest(version=version):
                self.command_log.write_text("")
                apks = ("lantern installer.apk", "lantern installer-armv7.apk")
                result = self.verify(version, *apks, versions=dict.fromkeys(apks, version))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    [json.loads(line) for line in self.command_log.read_text().splitlines()],
                    [["manifest", "version-name", apk] for apk in apks],
                )
                for apk in apks:
                    self.assertIn(f"Verified {apk} versionName={version}", result.stdout)

    def test_missing_beta_suffix_in_either_apk_fails(self) -> None:
        apks = ("app.apk", "app-armv7.apk")
        for mismatched in apks:
            with self.subTest(mismatched=mismatched):
                versions = dict.fromkeys(apks, "10.0.3-beta-10")
                versions[mismatched] = "10.0.3"
                result = self.verify("10.0.3-beta-10", *apks, versions=versions)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    f"{mismatched} has versionName '10.0.3'; expected '10.0.3-beta-10'",
                    result.stderr,
                )

    def test_empty_manifest_version_fails(self) -> None:
        result = self.verify("10.0.3-beta-10", "app.apk")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("app.apk has an empty versionName", result.stderr)

    def test_missing_arguments_or_empty_expected_version_fail_before_inspection(self) -> None:
        for args in ((), ("10.0.3",), ("", "app.apk")):
            with self.subTest(args=args):
                result = self.verify(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Usage:", result.stderr)
                self.assertFalse(self.command_log.exists())

    def test_failed_analyzer_cannot_pass_with_matching_partial_output(self) -> None:
        result = self.verify(
            "10.0.3", "app.apk", versions={"app.apk": "10.0.3"}, ANALYZER_EXIT="1",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not read versionName from app.apk", result.stderr)
        self.assertNotIn("Verified", result.stdout)

    def test_missing_analyzer_fails(self) -> None:
        self.apkanalyzer.unlink()
        result = self.verify("10.0.3", "app.apk")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("apkanalyzer is not on PATH", result.stderr)


if __name__ == "__main__":
    unittest.main()
