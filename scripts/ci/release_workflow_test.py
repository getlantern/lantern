from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
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
            "INSTALLER_BASE_NAME": "lantern-installer",
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
        log = self.work / "commands.jsonl"
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    def run_step(self, name: str, job: str = "release-finalize", **env: str) -> subprocess.CompletedProcess:
        step = next(step for step in self.jobs[job]["steps"] if step["name"] == name)
        return subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c", step["run"]],
            cwd=self.work, env={**self.env, **env}, text=True, capture_output=True, timeout=10,
        )

    def run_s3_upload(self, build_type: str, platforms: str, **env: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["bash", str(ROOT / "scripts/ci/publish-to-s3.sh"),
             build_type, "9.2.0", "lantern-installer", platforms],
            cwd=self.work, env={**self.env, **env}, text=True, capture_output=True, timeout=10,
        )

    def resolve_test_run_setting(self, job: str, value: str, step_name: str | None = None) -> str:
        environment = dict(self.jobs[job].get("env", {}))
        if step_name:
            step = next(step for step in self.jobs[job]["steps"] if step["name"] == step_name)
            environment.update(step.get("env", {}))
        return re.sub(
            r"\$\{\{\s*needs\.set-metadata\.outputs\.is_test_run\s*\}\}", value,
            environment.get("IS_TEST_RUN", "false"),
        )

    def run_metadata(self, tag: str, existing_tags: tuple[str, ...] = ()) -> tuple[subprocess.CompletedProcess, dict[str, str]]:
        # The Linux runner uses Bash 4+; macOS's system Bash lacks associative arrays.
        shell = None
        for candidate in (shutil.which("bash"), "/opt/homebrew/bin/bash", "/usr/local/bin/bash"):
            if candidate and Path(candidate).is_file():
                version = subprocess.run(
                    [candidate, "-c", "test ${BASH_VERSINFO[0]} -ge 4"],
                    capture_output=True, timeout=10,
                )
                if version.returncode == 0:
                    shell = candidate
                    break
        if shell is None:
            self.skipTest("release metadata requires Bash 4 or newer")

        step = next(step for step in self.jobs["set-metadata"]["steps"] if step.get("id") == "meta")
        expressions = {
            "github.event_name": "push",
            "github.event.inputs.build_type": "",
            "github.event.inputs.platforms": "",
            "github.event.inputs.linux_arch": "",
            "github.event.inputs.publish_mobile_stores": "",
            "github.event.repository.default_branch": "main",
            "github.ref_name": tag,
        }
        script = re.sub(r"\$\{\{\s*(.*?)\s*\}\}", lambda match: expressions[match[1].strip()], step["run"])
        with tempfile.TemporaryDirectory(dir=self.work) as temporary:
            repo = Path(temporary)
            output = repo / "output"
            env = {
                **{key: value for key, value in self.env.items() if not key.startswith("GIT_")},
                "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
                "GITHUB_REF": f"refs/tags/{tag}", "GITHUB_RUN_NUMBER": "123",
                "GITHUB_OUTPUT": str(output),
            }
            for args in (
                ["init", "--quiet"],
                ["-c", "user.name=Release test", "-c", "user.email=release@example.com",
                 "commit", "--quiet", "--allow-empty", "-m", "Release fixture"],
                *(["tag", value] for value in dict.fromkeys((*existing_tags, tag))),
            ):
                subprocess.run(
                    ["git", *args], cwd=repo, env=env, check=True,
                    text=True, capture_output=True, timeout=10,
                )
            (repo / "scripts").symlink_to(ROOT / "scripts", target_is_directory=True)
            result = subprocess.run(
                [shell, "-e", "-o", "pipefail", "-c", script],
                cwd=repo, env=env, text=True, capture_output=True, timeout=10,
            )
            outputs = dict(line.split("=", 1) for line in output.read_text().splitlines()) if output.exists() else {}
            return result, outputs

    def test_numbered_beta_metadata_preserves_version_and_platform_storage(self) -> None:
        for platform in ("all", "windows", "macos", "linux", "android", "ios"):
            with self.subTest(platform=platform):
                suffix = "" if platform == "all" else f"-{platform}"
                tag = f"v10.0.4-beta.10{suffix}"
                result, outputs = self.run_metadata(
                    tag, ("v10.0.3", "v10.0.3-beta-10", "v10.0.4-beta.9"),
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(outputs["build_type"], "beta")
                self.assertEqual(outputs["release_tag"], tag)
                self.assertEqual(outputs["version"], "10.0.4-beta.10")
                self.assertEqual(outputs["storage_version"], tag[1:])
                self.assertEqual(outputs["platform"], platform)
                self.assertEqual(outputs["linux_arch"], "all" if platform in ("all", "linux") else "amd64")

    def test_stable_metadata_promotes_the_same_base_beta(self) -> None:
        for platform in ("all", "android"):
            with self.subTest(platform=platform):
                suffix = "" if platform == "all" else f"-{platform}"
                tag = f"v10.0.4{suffix}"
                result, outputs = self.run_metadata(tag, ("v10.0.4-beta.10",))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(outputs["build_type"], "production")
                self.assertEqual(outputs["version"], "10.0.4")
                self.assertEqual(outputs["storage_version"], tag[1:])
                self.assertEqual(outputs["platform"], platform)

    def test_legacy_and_malformed_beta_tags_fail_before_metadata_output(self) -> None:
        for tag in (
            "v10.0.4-beta", "v10.0.4-beta-10", "v10.0.4-beta10",
            "v10.0.4-beta.01", "v10.0.4-beta.ten", "v10.0.4-beta.10-plan9",
        ):
            with self.subTest(tag=tag):
                result, outputs = self.run_metadata(tag, ("v10.0.3",))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("not a valid release version", result.stderr)
                self.assertEqual(outputs, {})

    def test_same_base_beta_migration_fails_before_metadata_output(self) -> None:
        for existing in ("v10.0.3-beta-10", "v10.0.3"):
            with self.subTest(existing=existing):
                result, outputs = self.run_metadata("v10.0.3-beta.11", (existing,))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("needs a higher base", result.stderr)
                self.assertEqual(outputs, {})

    def test_backwards_beta_tag_fails_before_metadata_output(self) -> None:
        result, outputs = self.run_metadata("v10.0.4-beta.9", ("v10.0.4-beta.10",))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("would go backwards", result.stderr)
        self.assertEqual(outputs, {})

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
        self.assertIn("::error::Failed to promote download aliases", result.stdout)
        self.assertIn("s3://release-test/releases/production/9.2.0/", result.stdout)
        self.assertEqual([command[0] for command in self.commands()], ["aws"])

    def test_alias_verification_failure_reports_an_error(self) -> None:
        result = self.run_step("Promote and verify download aliases", FAIL_COMMAND="python3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("::error::Release alignment verification failed for v9.2.0", result.stdout)
        self.assertEqual([command[0] for command in self.commands()], ["aws", "python3"])

    def test_unpublished_release_reports_an_error(self) -> None:
        result = self.run_step("Report unpublished release")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("::error::Release publication failed", result.stdout)

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
                for abi_suffix in ("", "-armv7"):
                    (directory / f"lantern-installer{suffix}{abi_suffix}.apk").write_bytes(b"installer")
                (self.work / "commands.jsonl").write_text("")
                result = self.run_s3_upload(build_type, "android")
                self.assertEqual(result.returncode, 0, result.stderr)
                destinations = [command[4] for command in self.commands()]
                # Both APKs, plus their nightly "latest" aliases.
                self.assertEqual(len(destinations), 4 if build_type == "nightly" else 2)
                self.assertIn(f"/{build_type}/9.2.0/", destinations[0])
                self.assertTrue(any(d.endswith(f"/lantern-installer{suffix}-armv7.apk") for d in destinations))
                checksum = hashlib.sha256(b"installer").hexdigest()
                for command in self.commands():
                    self.assertEqual(command[-2:], ["--metadata", f"sha256={checksum}"])

    def test_branch_nightly_uploads_without_replacing_shared_aliases(self) -> None:
        directory = self.work / "lantern-installer-apk"
        directory.mkdir()
        filenames = ("lantern-installer-nightly.apk", "lantern-installer-nightly-armv7.apk")
        for filename in filenames:
            (directory / filename).write_bytes(b"branch installer")

        result = self.run_s3_upload(
            "nightly", "android", IS_TEST_RUN=self.resolve_test_run_setting("upload-s3", "true"),
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [command[4] for command in self.commands()],
            [f"s3://release-test/releases/nightly/9.2.0/{filename}" for filename in filenames],
        )
        self.assertNotIn("https://s3.amazonaws.com/release-test/releases/nightly/latest/", result.stdout)

    def test_nightly_download_messages_point_to_the_published_artifacts(self) -> None:
        filenames = [
            "lantern-installer-nightly.dmg", "lantern-installer-nightly.exe",
            "lantern-installer-nightly.apk", "lantern-installer-nightly-armv7.apk",
            *[f"lantern-installer-nightly{suffix}.{extension}"
              for suffix in ("", "-arm64") for extension in ("deb", "rpm", "pkg.tar.zst")],
        ]
        for is_test_run in ("false", "true"):
            for message_format in ("slack", "release-notes"):
                with self.subTest(is_test_run=is_test_run, message_format=message_format):
                    if message_format == "slack":
                        setting = self.resolve_test_run_setting("release-success-notify", is_test_run, "Format Slack message")
                    else:
                        setting = self.resolve_test_run_setting("upload-release-artifacts", is_test_run)
                    result = subprocess.run(
                        ["bash", str(ROOT / "scripts/ci/format.sh"), message_format],
                        cwd=self.work,
                        env={
                            **self.env, "BUILD_TYPE": "nightly", "IS_TEST_RUN": setting,
                            "PLATFORM": "macos,windows,android,linux",
                            "GITHUB_REF_NAME": "feature/test" if is_test_run == "true" else "main",
                            "WORKFLOW_URL": "https://github.com/getlantern/lantern/actions/runs/123",
                        },
                        text=True, capture_output=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    for filename in filenames:
                        versioned = f"https://s3.amazonaws.com/release-test/releases/nightly/9.2.0/{filename}"
                        latest = f"https://s3.amazonaws.com/release-test/releases/nightly/latest/{filename}"
                        self.assertIn(versioned, result.stdout)
                        self.assertEqual(result.stdout.count(latest), 0 if is_test_run == "true" else 1)

    def test_successful_branch_nightlies_can_upload_and_notify(self) -> None:
        def eligible(job_name: str, is_test_run: str, *, cancelled: bool = False,
                     failed_job: str | None = None) -> bool:
            # Exercise the workflow's conditions with realistic nightly results.
            values = {f"{name}.result": "success" for name in self.jobs}
            for name in ("upload-google-play", "upload-testflight", "publish-update-metadata", "verify-update-service"):
                values[f"{name}.result"] = "skipped"
            values.update({
                "set-metadata.outputs.is_test_run": is_test_run,
                "set-metadata.outputs.build_type": "nightly",
            })
            if failed_job:
                values[f"{failed_job}.result"] = "failure"
            condition = re.sub(
                r"needs\.([\w.-]+)", lambda match: repr(values[match[1]]),
                self.jobs[job_name]["if"],
            )
            condition = condition.replace("always()", "True").replace("cancelled()", str(cancelled))
            condition = re.sub(r"!(?!=)", " not ", condition).replace("&&", " and ").replace("||", " or ")
            return eval(" ".join(condition.split()), {"__builtins__": {}}, {})

        for is_test_run in ("false", "true"):
            for job in ("upload-s3", "upload-release-artifacts", "release-success-notify"):
                with self.subTest(is_test_run=is_test_run, job=job):
                    self.assertTrue(eligible(job, is_test_run))
                    self.assertFalse(eligible(job, is_test_run, cancelled=True))
                    self.assertFalse(eligible(job, is_test_run, failed_job="nightly-gate"))
            for failed_job in ("upload-s3", "upload-release-artifacts", "release-finalize"):
                with self.subTest(is_test_run=is_test_run, failed_job=failed_job):
                    self.assertFalse(eligible("release-success-notify", is_test_run, failed_job=failed_job))

    def test_incomplete_candidate_set_blocks_all_uploads(self) -> None:
        directory = self.work / "lantern-installer-dmg"
        directory.mkdir()
        for build_type in ("production", "beta", "nightly"):
            with self.subTest(build_type=build_type):
                (self.work / "commands.jsonl").write_text("")
                suffix = "" if build_type == "production" else f"-{build_type}"
                (directory / f"lantern-installer{suffix}.dmg").write_bytes(b"installer")
                result = self.run_s3_upload(build_type, "macos,windows")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Required windows release artifact is missing", result.stderr)
                self.assertEqual(self.commands(), [])
                result = self.run_step(
                    "Upload artifacts to GitHub Release", job="upload-release-artifacts",
                    BUILD_TYPE=build_type, PLATFORM="macos,windows",
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Required windows release artifact is missing", result.stderr)
                self.assertEqual(self.commands(), [])

    def test_missing_arm64_package_blocks_all_github_uploads(self) -> None:
        for suffix in ("", "-arm64"):
            for extension, directory_suffix in (("deb", "deb"), ("rpm", "rpm"), ("pkg.tar.zst", "pkg")):
                if suffix == "-arm64" and extension == "pkg.tar.zst":
                    continue
                directory = self.work / f"lantern-installer-{directory_suffix}{suffix}"
                directory.mkdir()
                (directory / f"lantern-installer{suffix}.{extension}").write_bytes(b"installer")
        result = self.run_step(
            "Upload artifacts to GitHub Release", job="upload-release-artifacts",
            PLATFORM="linux", LINUX_ARCH="all",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("lantern-installer-arm64.pkg.tar.zst", result.stderr)
        self.assertEqual(self.commands(), [])

    def test_complete_candidates_upload_to_github(self) -> None:
        for extension in ("dmg", "exe"):
            directory = self.work / f"lantern-installer-{extension}"
            directory.mkdir()
            (directory / f"lantern-installer.{extension}").write_bytes(b"installer")
        result = self.run_step(
            "Upload artifacts to GitHub Release", job="upload-release-artifacts",
            PLATFORM="macos,windows",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [
            ["gh", "release", "upload", "v9.2.0", f"lantern-installer-{extension}/lantern-installer.{extension}", "--clobber"]
            for extension in ("dmg", "exe")
        ])

    def test_missing_requested_github_artifact_fails_for_every_channel(self) -> None:
        for build_type in ("production", "beta", "nightly"):
            with self.subTest(build_type=build_type):
                result = self.run_step(
                    "Upload artifacts to GitHub Release", job="upload-release-artifacts",
                    BUILD_TYPE=build_type, PLATFORM="windows",
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Required windows release artifact is missing", result.stderr)
                self.assertEqual(self.commands(), [])

    def test_failed_upload_does_not_promote_nightly_alias(self) -> None:
        directory = self.work / "lantern-installer-apk"
        directory.mkdir()
        for name in ("lantern-installer-nightly.apk", "lantern-installer-nightly-armv7.apk"):
            (directory / name).write_bytes(b"installer")
        result = self.run_s3_upload("nightly", "android", FAIL_COMMAND="aws")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.commands()), 1)
        self.assertIn("/nightly/9.2.0/", self.commands()[0][4])

    def test_failed_checksum_blocks_upload(self) -> None:
        directory = self.work / "lantern-installer-apk"
        directory.mkdir()
        for name in ("lantern-installer.apk", "lantern-installer-armv7.apk"):
            (directory / name).write_bytes(b"installer")
        checksum = self.bin / "sha256sum"
        checksum.write_text("#!/bin/sh\nexit 1\n")
        checksum.chmod(0o755)
        result = self.run_s3_upload("production", "android")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_linux_uploads_respect_architecture_and_legacy_directory(self) -> None:
        expected = {"amd64": set(), "arm64": set()}
        for arch, suffix in (("amd64", ""), ("arm64", "-arm64")):
            for extension, directory_suffix in (("deb", "deb"), ("rpm", "rpm"), ("pkg.tar.zst", "pkg")):
                directory = self.work / f"lantern-installer-{directory_suffix}{suffix}"
                directory.mkdir()
                filename = f"lantern-installer{suffix}.{extension}"
                (directory / filename).write_bytes(b"installer")
                expected[arch].add(filename)

        for arch in ("amd64", "arm64", "all"):
            with self.subTest(arch=arch):
                wanted = expected[arch] if arch != "all" else expected["amd64"] | expected["arm64"]
                (self.work / "commands.jsonl").write_text("")
                result = self.run_s3_upload("production", "linux", LINUX_ARCH=arch)
                self.assertEqual(result.returncode, 0, result.stderr)
                filenames = {Path(command[3]).name for command in self.commands()}
                self.assertEqual(filenames, wanted)

                (self.work / "commands.jsonl").write_text("")
                result = self.run_step(
                    "Upload artifacts to GitHub Release", job="upload-release-artifacts",
                    PLATFORM="linux", LINUX_ARCH=arch,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                filenames = {Path(command[4]).name for command in self.commands()}
                self.assertEqual(filenames, wanted)

    def test_publication_and_success_notification_wait_for_verification(self) -> None:
        publish = next(step for step in self.jobs["release-finalize"]["steps"] if step.get("id") == "publish")
        self.assertIn("needs.verify-release-assets.result == 'success'", publish["if"])
        notify = self.jobs["release-success-notify"]
        self.assertIn("verify-update-service", notify["needs"])
        self.assertIn("needs.verify-update-service.result == 'success'", notify["if"])


if __name__ == "__main__":
    unittest.main()
