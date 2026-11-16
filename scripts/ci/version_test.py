#!/usr/bin/env python3

from __future__ import annotations

import contextlib
import os
import pathlib
import re
import subprocess
import tempfile
import unittest
from collections.abc import Iterator


SCRIPT = pathlib.Path(__file__).resolve().with_name("version.sh")
PLATFORMS = ("android", "ios", "linux", "macos", "windows")


class VersionScriptTest(unittest.TestCase):
    @contextlib.contextmanager
    def repository(self, tags: tuple[str, ...]) -> Iterator[tuple[pathlib.Path, dict[str, str]]]:
        with tempfile.TemporaryDirectory(prefix="lantern-version-test-") as directory:
            repository = pathlib.Path(directory)
            env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            env.update(
                GIT_CONFIG_GLOBAL=os.devnull,
                GIT_CONFIG_NOSYSTEM="1",
                GIT_TERMINAL_PROMPT="0",
            )

            def git(*args: str) -> None:
                subprocess.run(
                    ["git", *args],
                    cwd=repository,
                    env=env,
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )

            git("-c", "init.defaultBranch=main", "init")
            git("config", "user.name", "Version Script Test")
            git("config", "user.email", "version-test@example.invalid")
            git("config", "commit.gpgsign", "false")
            git("config", "tag.gpgsign", "false")
            git("config", "core.hooksPath", os.devnull)
            git("commit", "--allow-empty", "-m", "Version test fixture")
            for tag in tags:
                git("tag", tag)
            yield repository, env

    def run_version(self, *args: str, tags: tuple[str, ...] = ()) -> subprocess.CompletedProcess[str]:
        with self.repository(tags) as (repository, env):
            return subprocess.run(
                ["bash", str(SCRIPT), *args],
                cwd=repository,
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )

    def assert_output(self, expected: str, *args: str, tags: tuple[str, ...] = ()) -> None:
        result = self.run_version(*args, tags=tags)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), expected)

    def assert_rejected(self, *args: str, tags: tuple[str, ...] = ()) -> None:
        result = self.run_version(*args, tags=tags)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stderr.strip(), "Rejected versions should explain the failure")

    def test_validate_accepts_stable_and_numbered_beta_versions(self) -> None:
        for version in ("0.0.0", "1.2.3", "1.2.3-beta.0", "1.2.3-beta.1", "1.2.3-beta.100"):
            for prefix in ("", "v"):
                with self.subTest(version=version, prefix=prefix):
                    self.assert_output(version, "validate", prefix + version)

    def test_validate_accepts_known_platform_suffixes(self) -> None:
        for platform in PLATFORMS:
            for version in ("1.2.3", "1.2.3-beta.10"):
                candidate = f"{version}-{platform}"
                with self.subTest(candidate=candidate):
                    self.assert_output(candidate, "validate", "v" + candidate)

    def test_validate_rejects_legacy_beta_names_for_new_releases(self) -> None:
        for suffix in ("beta", "beta-10", "beta10"):
            for platform in ("", "-android"):
                with self.subTest(suffix=suffix, platform=platform):
                    self.assert_rejected("validate", f"v1.2.3-{suffix}{platform}")

    def test_validate_rejects_invalid_release_grammar(self) -> None:
        invalid_versions = (
            "1.2",
            "01.2.3",
            "1.02.3",
            "1.2.03",
            "1.2.3.4",
            "1.2.3garbage",
            "1.2.3-beta.",
            "1.2.3-beta.01",
            "1.2.3-beta.-1",
            "1.2.3-beta.1.2",
            "1.2.3-beta.e2e.123",
            "1.2.3-beta.1-unknown",
            "1.2.3-beta.1-android-windows",
            "1.2.3-unknown",
            "1.2.3-beta.1+build.2",
            "1.2.3+build.2",
            "1.2.3-abcdef0-20261020T120000Z",
        )
        for version in invalid_versions:
            with self.subTest(version=version):
                self.assert_rejected("validate", version)

    def test_generate_beta_starts_above_a_stable_release(self) -> None:
        self.assert_output("10.0.4-beta.1", "generate", "beta", tags=("v10.0.3",))

    def test_generate_beta_starts_above_legacy_beta_releases(self) -> None:
        for suffix in ("beta", "beta-10", "beta10"):
            for platform in ("", "-android", "-ios", "-linux", "-macos", "-windows"):
                tag = f"v10.0.3-{suffix}{platform}"
                with self.subTest(tag=tag):
                    self.assert_output("10.0.4-beta.1", "generate", "beta", tags=(tag,))

    def test_generate_beta_increments_numeric_counters(self) -> None:
        cases = (
            (("v10.0.4-beta.0",), "10.0.4-beta.1"),
            (("v10.0.4-beta.9",), "10.0.4-beta.10"),
            (("v10.0.4-beta.9", "v10.0.4-beta.10"), "10.0.4-beta.11"),
            (("v10.0.4-beta.99",), "10.0.4-beta.100"),
            (("v10.0.4-beta.99", "v10.0.4-beta.100"), "10.0.4-beta.101"),
        )
        for tags, expected in cases:
            with self.subTest(tags=tags):
                self.assert_output(expected, "generate", "beta", tags=tags)

    def test_generate_beta_uses_highest_platform_counter(self) -> None:
        self.assert_output(
            "10.0.4-beta.11",
            "generate",
            "beta",
            tags=("v10.0.4-beta.9-windows", "v10.0.4-beta.10-android"),
        )

    def test_generate_beta_compares_base_versions_numerically(self) -> None:
        self.assert_output(
            "10.0.0-beta.2",
            "generate",
            "beta",
            tags=("v9.99.99", "v10.0.0-beta.1"),
        )
        self.assert_output(
            "10.10.0-beta.2",
            "generate",
            "beta",
            tags=("v10.9.99", "v10.10.0-beta.1"),
        )

    def test_generate_beta_starts_new_base_after_stable_promotion(self) -> None:
        for stable_tag in ("v10.0.4", "v10.0.4-android"):
            with self.subTest(stable_tag=stable_tag):
                self.assert_output(
                    "10.0.5-beta.1",
                    "generate",
                    "beta",
                    tags=("v10.0.4-beta.10", stable_tag),
                )

    def test_generate_beta_starts_new_base_when_legacy_and_canonical_tags_coexist(self) -> None:
        self.assert_output(
            "10.0.5-beta.1",
            "generate",
            "beta",
            tags=("v10.0.4-beta-9", "v10.0.4-beta.10"),
        )

    def test_lower_legacy_and_stable_bases_do_not_block_canonical_beta_continuation(self) -> None:
        tags = ("v10.0.2", "v10.0.3-beta10", "v10.0.4-beta.9")
        self.assert_output("10.0.4-beta.10", "generate", "beta", tags=tags)
        self.assert_output("10.0.4-beta.10", "validate", "v10.0.4-beta.10", tags=tags)

    def test_validate_requires_higher_base_than_legacy_betas(self) -> None:
        for suffix in ("beta", "beta-10", "beta10"):
            for platform in ("", "-android"):
                tag = f"v10.0.3-{suffix}{platform}"
                with self.subTest(tag=tag):
                    self.assert_rejected("validate", "v10.0.3-beta.11", tags=(tag,))
                    self.assert_output(
                        "10.0.4-beta.1", "validate", "v10.0.4-beta.1", tags=(tag,)
                    )

    def test_validate_rejects_beta_at_a_stable_base(self) -> None:
        for stable_tag in ("v10.0.4", "v10.0.4-ios"):
            with self.subTest(stable_tag=stable_tag):
                self.assert_rejected("validate", "v10.0.4-beta.100", tags=(stable_tag,))

    def test_validate_rejects_lower_base_than_any_release_kind(self) -> None:
        for tag in ("v10.0.4", "v10.0.4-beta.1", "v10.0.4-beta-1", "v10.0.4-beta1-macos"):
            for candidate in ("v10.0.3", "v10.0.3-beta.100"):
                with self.subTest(tag=tag, candidate=candidate):
                    self.assert_rejected("validate", candidate, tags=(tag,))

    def test_validate_rejects_lower_numeric_beta_counter(self) -> None:
        for current, candidate in (
            ("v10.0.4-beta.10", "v10.0.4-beta.9"),
            ("v10.0.4-beta.100-android", "v10.0.4-beta.99-windows"),
        ):
            with self.subTest(current=current, candidate=candidate):
                self.assert_rejected("validate", candidate, tags=(current, candidate))

    def test_validate_accepts_current_pushed_tag(self) -> None:
        for tag in ("v10.0.4", "v10.0.4-beta.10", "v10.0.4-beta.10-android"):
            with self.subTest(tag=tag):
                self.assert_output(tag.removeprefix("v"), "validate", tag, tags=(tag,))

    def test_validate_accepts_same_application_version_for_another_platform(self) -> None:
        for version in ("10.0.4", "10.0.4-beta.10"):
            with self.subTest(version=version):
                self.assert_output(
                    f"{version}-windows",
                    "validate",
                    f"v{version}-windows",
                    tags=(f"v{version}-android",),
                )

    def test_current_pushed_beta_does_not_bypass_migration_guard(self) -> None:
        candidate = "v10.0.4-beta.10"
        for older in ("v10.0.4", "v10.0.4-beta-9"):
            with self.subTest(older=older):
                self.assert_rejected("validate", candidate, tags=(candidate, older))

    def test_validate_allows_stable_promotion_at_beta_base(self) -> None:
        self.assert_output("10.0.4", "validate", "v10.0.4", tags=("v10.0.4-beta.100",))

    def test_release_history_ignores_nightly_and_unrelated_tags(self) -> None:
        tags = (
            "v10.0.4-beta.9",
            "v99.0.0-abcdef0-20261020T120000Z",
            "v99.0.0-beta.e2e.123",
            "v99.0.0-rc.1",
            "v99.0.0-unknown",
            "v99.0.0-beta.01",
            "unrelated-100.0.0",
        )
        self.assert_output("10.0.4-beta.10", "generate", "beta", tags=tags)
        self.assert_output("10.0.4-beta.10", "validate", "v10.0.4-beta.10", tags=tags)

    def test_generation_requires_recognized_release_history(self) -> None:
        for tags in ((), ("v99.0.0-abcdef0-20261020T120000Z", "unrelated")):
            for build_type in ("beta", "nightly"):
                with self.subTest(tags=tags, build_type=build_type):
                    self.assert_rejected("generate", build_type, tags=tags)

    def test_nightly_uses_highest_recognized_release_base(self) -> None:
        cases = (
            (("v10.0.3", "v10.0.4-beta.100-android"), "10.0.5"),
            (("v10.0.4-beta.100", "v10.0.5-ios"), "10.0.6"),
            (("v10.0.4-beta10",), "10.0.5"),
        )
        for tags, base in cases:
            with self.subTest(tags=tags):
                result = self.run_version(
                    "generate",
                    "nightly",
                    tags=(*tags, "v99.0.0-abcdef0-20261020T120000Z"),
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertRegex(
                    result.stdout.strip(),
                    rf"^{re.escape(base)}-[0-9a-f]{{7,}}-[0-9]{{8}}T[0-9]{{6}}Z$",
                )

    def test_extract_supports_existing_build_version_formats(self) -> None:
        versions = (
            "1.2.3",
            "v1.2.3",
            "1.2.3-beta.10",
            "v1.2.3-beta.10-android",
            "1.2.3-beta",
            "1.2.3-beta-10",
            "1.2.3-beta10-macos",
            "1.2.3-abcdef0-20261020T120000Z",
            "1.2.3+123",
            "1.2.3-beta-10+build.123",
        )
        for version in versions:
            with self.subTest(version=version):
                self.assert_output("1.2.3", "extract", version, tags=("v99.0.0",))

    def test_extract_rejects_versions_without_a_valid_base(self) -> None:
        for version in ("garbage", "v1.2", "1.2.03"):
            with self.subTest(version=version):
                self.assert_rejected("extract", version)


if __name__ == "__main__":
    unittest.main()
