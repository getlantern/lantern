#!/usr/bin/env python3

from __future__ import annotations

import base64
import hashlib
import pathlib
import sys
import tempfile
from unittest import TestCase, main

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import generate_update_metadata


class GenerateUpdateMetadataTest(TestCase):
    def test_release_channel_maps_build_types(self) -> None:
        cases = {
            "production": "stable",
            "prod": "stable",
            "stable": "stable",
            "": "stable",
            "beta": "beta",
            "nightly": "nightly",
            "internal": "nightly",
            "dev": "nightly",
            "development": "nightly",
        }
        for build_type, channel in cases.items():
            with self.subTest(build_type=build_type):
                self.assertEqual(
                    generate_update_metadata.release_channel(build_type),
                    channel,
                )

        with self.assertRaises(ValueError):
            generate_update_metadata.release_channel("qa")

    def test_artifact_info_matches_update_service_artifacts(self) -> None:
        cases = {
            "lantern-installer-beta.dmg": ("macos", "darwin", "amd64"),
            "lantern-installer-beta.exe": ("windows", "windows", "amd64"),
            "lantern-installer-beta.apk": ("android", "android", "arm"),
            "lantern-installer-beta.deb": ("linux", "linux", "amd64"),
            "lantern-installer-beta-arm64.deb": ("linux", "linux", "arm64"),
            "lantern-installer-beta.ipa": None,
            "lantern-installer-beta.rpm": None,
            "lantern-installer-beta.pkg.tar.zst": None,
            "notes.txt": None,
        }
        for filename, info in cases.items():
            with self.subTest(filename=filename):
                self.assertEqual(
                    generate_update_metadata.artifact_info(filename),
                    info,
                )

    def test_sidecar_for_builds_json_shape(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-beta.apk"
            artifact.write_bytes(b"apk bytes")

            metadata = generate_update_metadata.sidecar_for(
                artifact,
                "beta",
                "9.2.0-beta",
                "lantern.io",
            )

        self.assertEqual(
            metadata,
            {
                "schema_version": 1,
                "app": "lantern",
                "version": "9.2.0-beta",
                "short_version": "9.2.0",
                "channel": "beta",
                "build_type": "beta",
                "platform": "android",
                "os": "android",
                "arch": "arm",
                "filename": "lantern-installer-beta.apk",
                "url": (
                    "https://s3.amazonaws.com/lantern.io/releases/"
                    "beta/9.2.0-beta/lantern-installer-beta.apk"
                ),
                "size": len(b"apk bytes"),
                "sha256": hashlib.sha256(b"apk bytes").hexdigest(),
            },
        )

    def test_sidecar_for_normalizes_channel_without_changing_release_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-production.deb"
            artifact.write_bytes(b"deb bytes")

            metadata = generate_update_metadata.sidecar_for(
                artifact,
                "production",
                "9.2.0",
                "lantern.io",
            )

        self.assertEqual(metadata["channel"], "stable")
        self.assertEqual(metadata["build_type"], "production")
        self.assertEqual(
            metadata["url"],
            (
                "https://s3.amazonaws.com/lantern.io/releases/"
                "production/9.2.0/lantern-installer-production.deb"
            ),
        )

    def test_sidecar_for_skips_unknown_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-beta.ipa"
            artifact.write_bytes(b"ios bytes")

            metadata = generate_update_metadata.sidecar_for(
                artifact,
                "beta",
                "9.2.0-beta",
                "lantern.io",
            )

        self.assertIsNone(metadata)

    def test_sidecar_for_adds_sparkle_signature_for_desktop(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-beta.dmg"
            artifact.write_bytes(b"dmg bytes")
            signature = base64.b64encode(b"s" * 64).decode("ascii")
            (pathlib.Path(tmp) / f"{artifact.name}.sparkle-signature").write_text(
                signature,
                encoding="ascii",
            )

            metadata = generate_update_metadata.sidecar_for(
                artifact,
                "beta",
                "9.2.0-beta",
                "lantern.io",
                pathlib.Path(tmp),
                "920",
            )

        self.assertEqual(metadata["platform"], "macos")
        self.assertEqual(metadata["sparkle_version"], "920")
        self.assertEqual(metadata["sparkle_ed_signature"], signature)

    def test_sidecar_for_adds_dsa_signature_for_windows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-beta.exe"
            artifact.write_bytes(b"exe bytes")
            signature = "MAMCAQE="
            (pathlib.Path(tmp) / f"{artifact.name}.sparkle-signature").write_text(
                signature,
                encoding="ascii",
            )

            metadata = generate_update_metadata.sidecar_for(
                artifact,
                "beta",
                "9.2.0-beta",
                "lantern.io",
                pathlib.Path(tmp),
                "920",
            )

        self.assertEqual(metadata["platform"], "windows")
        self.assertEqual(metadata["sparkle_version"], "920")
        self.assertEqual(metadata["sparkle_dsa_signature"], signature)
        self.assertNotIn("sparkle_ed_signature", metadata)

    def test_updater_signature_rejects_invalid_base64(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-beta.exe"
            artifact.write_bytes(b"exe bytes")
            (pathlib.Path(tmp) / f"{artifact.name}.sparkle-signature").write_text(
                "not a signature",
                encoding="ascii",
            )

            with self.assertRaisesRegex(RuntimeError, "invalid DSA signature"):
                generate_update_metadata.updater_signature(
                    artifact,
                    pathlib.Path(tmp),
                    "DSA",
                )

    def test_updater_signature_requires_native_runner_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = pathlib.Path(tmp) / "lantern-installer-beta.dmg"
            artifact.write_bytes(b"dmg bytes")

            with self.assertRaisesRegex(RuntimeError, "missing EdDSA signature"):
                generate_update_metadata.updater_signature(
                    artifact,
                    pathlib.Path(tmp),
                    "EdDSA",
                )


if __name__ == "__main__":
    main()
