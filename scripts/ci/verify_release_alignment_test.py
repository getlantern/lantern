#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import verify_release_alignment


class VerifyReleaseAlignmentTest(unittest.TestCase):
    def config(self, **overrides: object) -> verify_release_alignment.Config:
        values: dict[str, object] = {
            "repository": "getlantern/lantern",
            "release_tag": "v9.2.0-beta",
            "version": "9.2.0-beta",
            "storage_version": "9.2.0-beta",
            "build_type": "beta",
            "platforms": verify_release_alignment.normalize_platforms("all"),
            "linux_arch": "all",
            "bucket": "lantern.io",
            "expected_commit": "a" * 40,
        }
        values.update(overrides)
        return verify_release_alignment.Config(**values)

    def test_required_assets_cover_all_platforms_and_linux_architectures(self) -> None:
        assets = verify_release_alignment.required_asset_names(
            "beta",
            verify_release_alignment.normalize_platforms("all"),
            "all",
        )

        self.assertEqual(
            assets,
            {
                "lantern-installer-beta.apk",
                "lantern-installer-beta.deb",
                "lantern-installer-beta.dmg",
                "lantern-installer-beta.exe",
                "lantern-installer-beta.ipa",
                "lantern-installer-beta.pkg.tar.zst",
                "lantern-installer-beta.rpm",
                "lantern-installer-beta-arm64.deb",
                "lantern-installer-beta-arm64.pkg.tar.zst",
                "lantern-installer-beta-arm64.rpm",
            },
        )

    def test_required_assets_respect_platform_and_architecture(self) -> None:
        assets = verify_release_alignment.required_asset_names(
            "production",
            verify_release_alignment.normalize_platforms("linux,macos"),
            "arm64",
        )

        self.assertEqual(
            assets,
            {
                "lantern-installer.dmg",
                "lantern-installer-arm64.deb",
                "lantern-installer-arm64.pkg.tar.zst",
                "lantern-installer-arm64.rpm",
            },
        )

    def test_validate_release_accepts_complete_draft(self) -> None:
        config = self.config(platforms=verify_release_alignment.normalize_platforms("macos"))
        required = verify_release_alignment.required_asset_names("beta", config.platforms, "all")
        release = {
            "tag_name": config.release_tag,
            "draft": True,
            "prerelease": True,
            "name": "Beta 9.2.0-beta",
            "assets": [
                {
                    "name": "lantern-installer-beta.dmg",
                    "size": 42,
                    "state": "uploaded",
                    "digest": f"sha256:{'a' * 64}",
                },
                {"name": "lantern-installer-beta.dmg.update.json", "size": 10, "state": "uploaded"},
            ],
        }

        verify_release_alignment.validate_release(release, config, required)

    def test_validate_release_rejects_missing_asset(self) -> None:
        config = self.config(platforms=verify_release_alignment.normalize_platforms("macos"))
        required = verify_release_alignment.required_asset_names("beta", config.platforms, "all")
        release = {
            "tag_name": config.release_tag,
            "draft": True,
            "prerelease": True,
            "name": "Beta 9.2.0-beta",
            "assets": [],
        }

        with self.assertRaisesRegex(
            verify_release_alignment.VerificationError,
            "missing assets: lantern-installer-beta.dmg",
        ):
            verify_release_alignment.validate_release(release, config, required)

    def test_validate_release_rejects_production_prerelease(self) -> None:
        config = self.config(
            release_tag="v9.2.0",
            version="9.2.0",
            build_type="production",
            platforms=verify_release_alignment.normalize_platforms("android"),
        )
        required = verify_release_alignment.required_asset_names(
            "production", config.platforms, "all"
        )
        release = {
            "tag_name": config.release_tag,
            "draft": True,
            "prerelease": True,
            "name": "Lantern 9.2.0",
            "assets": [
                {"name": "lantern-installer.apk", "size": 42, "state": "uploaded"},
            ],
        }

        with self.assertRaisesRegex(
            verify_release_alignment.VerificationError,
            "prerelease=True, want False",
        ):
            verify_release_alignment.validate_release(release, config, required)

    def test_platform_release_uses_base_application_version_in_title(self) -> None:
        config = self.config(
            release_tag="v9.2.0-android",
            version="9.2.0",
            storage_version="9.2.0-android",
            build_type="production",
            platforms=verify_release_alignment.normalize_platforms("android"),
        )
        required = verify_release_alignment.required_asset_names(
            "production", config.platforms, "amd64"
        )
        release = {
            "tag_name": "v9.2.0-android",
            "draft": True,
            "prerelease": False,
            "name": "Lantern 9.2.0",
            "assets": [
                {"name": "lantern-installer.apk", "size": 42, "state": "uploaded"},
            ],
        }

        verify_release_alignment.validate_release(release, config, required)

    @mock.patch.object(verify_release_alignment, "request_json")
    def test_resolve_tag_commit_follows_annotated_tag(self, request_json: mock.Mock) -> None:
        request_json.side_effect = [
            {"object": {"type": "tag", "sha": "b" * 40}},
            {"object": {"type": "commit", "sha": "a" * 40}},
        ]

        self.assertEqual(
            verify_release_alignment.resolve_tag_commit(self.config()),
            "a" * 40,
        )

    @mock.patch.object(verify_release_alignment, "request_headers")
    def test_validate_aliases_requires_identical_content(self, request_headers: mock.Mock) -> None:
        request_headers.side_effect = [
            {
                "content-length": "42",
                "etag": '"versioned"',
                "x-amz-meta-sha256": "a" * 64,
            },
            {
                "content-length": "42",
                "etag": '"latest"',
                "x-amz-meta-sha256": "b" * 64,
            },
        ]
        config = self.config(expect_draft=False, platforms=verify_release_alignment.normalize_platforms("macos"))

        with self.assertRaisesRegex(
            verify_release_alignment.VerificationError,
            "latest alias SHA-256 differs",
        ):
            verify_release_alignment.validate_assets(
                config,
                frozenset({"lantern-installer-beta.dmg"}),
                {
                    "lantern-installer-beta.dmg": {
                        "size": 42,
                        "digest": f"sha256:{'a' * 64}",
                    },
                },
            )

    @mock.patch.object(verify_release_alignment, "request_headers")
    def test_validate_aliases_matches_github_digest(self, request_headers: mock.Mock) -> None:
        headers = {
            "content-length": "42",
            "etag": '"same"',
            "x-amz-meta-sha256": "a" * 64,
        }
        request_headers.side_effect = [headers, {**headers, "etag": '"multipart-copy"'}]
        config = self.config(expect_draft=False, platforms=verify_release_alignment.normalize_platforms("macos"))

        verify_release_alignment.validate_assets(
            config,
            frozenset({"lantern-installer-beta.dmg"}),
            {
                "lantern-installer-beta.dmg": {
                    "size": 42,
                    "digest": f"sha256:{'a' * 64}",
                },
            },
        )

    @mock.patch.object(verify_release_alignment, "request_headers")
    def test_prepublication_checks_only_versioned_objects(self, request_headers: mock.Mock) -> None:
        request_headers.return_value = {
            "content-length": "42", "x-amz-meta-sha256": "a" * 64,
        }
        config = self.config()
        assets = {"lantern-installer-beta.dmg": {"size": 42, "digest": f"sha256:{'a' * 64}"}}
        verify_release_alignment.validate_assets(config, frozenset(assets), assets)
        request_headers.assert_called_once_with(
            "https://s3.amazonaws.com/lantern.io/releases/beta/9.2.0-beta/lantern-installer-beta.dmg"
        )

    @mock.patch.object(verify_release_alignment, "request_headers")
    def test_versioned_objects_must_match_github_before_promotion(self, request_headers: mock.Mock) -> None:
        request_headers.return_value = {
            "content-length": "42", "x-amz-meta-sha256": "b" * 64,
        }
        assets = {"lantern-installer-beta.dmg": {"size": 42, "digest": f"sha256:{'a' * 64}"}}
        with self.assertRaisesRegex(verify_release_alignment.VerificationError, "digests differ"):
            verify_release_alignment.validate_assets(
                self.config(), frozenset(assets), assets,
            )

    @mock.patch.object(verify_release_alignment, "validate_assets")
    @mock.patch.object(verify_release_alignment, "resolve_tag_commit", return_value="b" * 40)
    @mock.patch.object(verify_release_alignment, "request_json")
    def test_wrong_source_commit_blocks_release(self, request_json, resolve_tag, validate_aliases) -> None:
        request_json.return_value = {
            "tag_name": "v9.2.0-beta", "name": "Beta 9.2.0-beta",
            "draft": True, "prerelease": True,
            "assets": [{"name": "lantern-installer-beta.apk", "size": 42, "state": "uploaded"}],
        }
        with self.assertRaisesRegex(verify_release_alignment.VerificationError, "release tag points to"):
            verify_release_alignment.verify(self.config(platforms=frozenset({"android"})))
        validate_aliases.assert_not_called()


if __name__ == "__main__":
    unittest.main()
