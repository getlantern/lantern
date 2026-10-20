from __future__ import annotations

import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class AndroidVersionBuildTest(unittest.TestCase):
    def test_all_android_builds_preserve_the_release_version(self) -> None:
        cases = (
            # CI's shared pubspec has already lost the prerelease suffix.
            ("10.0.3-beta-10", "10.0.3+123", "10.0.3-beta-10"),
            ("10.0.3-beta-10+build.123", "10.0.3+123",
             "10.0.3-beta-10+build.123"),
            ("10.0.3", "10.0.3+123", "10.0.3"),
            ("10.0.4-a1b2c3d-20261020T040000Z", "10.0.4+123",
             "10.0.4-a1b2c3d-20261020T040000Z"),
            # Local builds without a release VERSION keep APP_VERSION's suffix.
            ("", "10.0.3-beta-10+123", "10.0.3-beta-10"),
            ("   ", "10.0.3-beta-10+123", "10.0.3-beta-10"),
            ("", "10.0.3+123", "10.0.3"),
        )
        with tempfile.TemporaryDirectory() as directory:
            for version, app_version, expected in cases:
                with self.subTest(version=version, app_version=app_version):
                    result = subprocess.run(
                        [
                            "make", "--no-print-directory", "-n",
                            "android-apk-release", "android-aab-release",
                            "android-debug-ci", "android-integration-apks",
                            "android-integration-test",
                            # No native build, identity generation, or recursive
                            # Make invocation should run during this dry run.
                            "MAKE=true", "GO_SOURCES=",
                            "ANDROID_GENERATE_IDENTITY_PROFILE=0",
                            "ANDROID_IDENTITY_PROFILE=",
                            f"BUILD_DIR={directory}/build",
                            f"BIN_DIR={directory}/bin",
                        ],
                        cwd=ROOT,
                        env={
                            **os.environ, "GITHUB_ACTIONS": "true",
                            "VERSION": version, "APP_VERSION": app_version,
                            "BUILD_TYPE": "beta",
                        },
                        text=True, capture_output=True, timeout=30,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    commands = [shlex.split(line) for line in result.stdout.splitlines()
                                if "flutter build " in line or
                                " -Plantern.versionName=" in line]
                    flutter = [args for args in commands if "flutter" in args]
                    gradle = [args for args in commands if args not in flutter]
                    # Both sideload ABIs, Play AAB, and debug APK.
                    self.assertEqual(len(flutter), 4, result.stdout)
                    for args in flutter:
                        self.assertIn(f"--build-name={expected}", args)
                    # Instrumentation APKs and connected-device test builds.
                    self.assertEqual(len(gradle), 2, result.stdout)
                    for args in gradle:
                        self.assertIn(f"-Plantern.versionName={expected}", args)


if __name__ == "__main__":
    unittest.main()
