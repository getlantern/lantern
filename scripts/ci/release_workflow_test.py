from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]


class ReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.jobs = yaml.safe_load((ROOT / ".github/workflows/release.yml").read_text())["jobs"]

    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.bin = self.work / "bin"
        self.bin.mkdir()
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "COMMAND_LOG": str(self.work / "commands.jsonl"),
            "GITHUB_OUTPUT": str(self.work / "output"),
            "BUILD_TYPE": "production", "PLATFORM": "all", "LINUX_ARCH": "all",
            "RELEASE_TAG": "v9.2.0", "VERSION": "9.2.0", "STORAGE_VERSION": "9.2.0",
            "BUCKET": "release-test", "GITHUB_REPOSITORY": "getlantern/lantern",
            "GITHUB_SHA": "a" * 40,
        }
        # Only the workflow's shell runs; external commands record their arguments.
        for name in ("gh", "aws", "python3"):
            command = self.bin / name
            command.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps([name, *sys.argv[1:]]) + "\\n")
if name == os.environ.get("FAIL_COMMAND"):
    sys.exit(1)
if name == "gh" and sys.argv[1:3] == ["release", "view"]:
    print(os.environ.get("IS_DRAFT", "true"))
''')
            command.chmod(0o755)

    def commands(self) -> list[list[str]]:
        return [json.loads(line) for line in (self.work / "commands.jsonl").read_text().splitlines()]

    def run_step(self, name: str, **env: str) -> subprocess.CompletedProcess:
        step = next(step for step in self.jobs["release-finalize"]["steps"] if step["name"] == name)
        return subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c", step["run"]],
            cwd=self.work, env={**self.env, **env}, text=True, capture_output=True, timeout=10,
        )

    def test_only_full_production_release_becomes_latest(self) -> None:
        for build_type, platform, latest in (
            ("production", "all", "true"), ("production", "ios", "false"),
            ("production", "macos", "false"), ("beta", "all", "false"),
        ):
            with self.subTest(build_type=build_type, platform=platform):
                result = self.run_step("Publish release on success", BUILD_TYPE=build_type, PLATFORM=platform)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"--latest={latest}", self.commands()[-1])
                self.assertIn("--draft=false", self.commands()[-1])

    def test_failed_publication_does_not_report_success(self) -> None:
        result = self.run_step("Publish release on success", FAIL_COMMAND="gh")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.work / "output").exists())

    def test_cleanup_preserves_published_release_after_api_error(self) -> None:
        result = self.run_step("Clean up draft release", IS_DRAFT="false")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.commands()), 1)
        self.assertEqual(self.commands()[0][1:3], ["release", "view"])

    def test_cleanup_can_delete_an_unpublished_draft(self) -> None:
        result = self.run_step("Clean up draft release")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands()[-1], ["gh", "release", "delete", "v9.2.0", "--yes"])

    def test_cleanup_stops_when_release_state_cannot_be_read(self) -> None:
        result = self.run_step("Clean up draft release", FAIL_COMMAND="gh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.commands()), 1)
        self.assertEqual(self.commands()[0][1:3], ["release", "view"])

    def test_alias_copy_failure_stops_verification(self) -> None:
        result = self.run_step("Promote and verify download aliases", FAIL_COMMAND="aws")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([command[0] for command in self.commands()], ["aws"])

    def test_alias_promotion_preserves_metadata_and_verifies_public_release(self) -> None:
        result = self.run_step("Promote and verify download aliases")
        self.assertEqual(result.returncode, 0, result.stderr)
        copy, verify = self.commands()
        self.assertIn("s3://release-test/releases/production/9.2.0/", copy)
        self.assertIn("s3://release-test/releases/production/latest/", copy)
        self.assertEqual(copy[-2:], ["--copy-props", "metadata-directive"])
        self.assertIn("--no-expect-draft", verify)

    def test_upload_stages_releases_but_promotes_nightlies(self) -> None:
        directory = self.work / "lantern-installer-apk"
        directory.mkdir()
        for build_type in ("production", "beta", "nightly"):
            with self.subTest(build_type=build_type):
                suffix = "" if build_type == "production" else f"-{build_type}"
                (directory / f"lantern-installer{suffix}.apk").write_bytes(b"installer")
                (self.work / "commands.jsonl").write_text("")
                result = subprocess.run(
                    ["bash", str(ROOT / "scripts/ci/publish-to-s3.sh"),
                     build_type, "9.2.0", "lantern-installer", "android"],
                    cwd=self.work, env=self.env, text=True, capture_output=True, timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                destinations = [command[4] for command in self.commands()]
                self.assertEqual(len(destinations), 2 if build_type == "nightly" else 1)
                self.assertIn(f"/{build_type}/9.2.0/", destinations[0])

    def test_publication_and_success_notification_wait_for_verification(self) -> None:
        publish = next(step for step in self.jobs["release-finalize"]["steps"] if step.get("id") == "publish")
        self.assertIn("needs.verify-release-assets.result == 'success'", publish["if"])
        notify = self.jobs["release-success-notify"]
        self.assertIn("verify-update-service", notify["needs"])
        self.assertIn("needs.verify-update-service.result == 'success'", notify["if"])


if __name__ == "__main__":
    unittest.main()
