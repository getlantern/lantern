#!/usr/bin/env python3

from __future__ import annotations

import base64
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import resolve_desktop_update_target as resolver


SIGNATURE = base64.b64encode(bytes(range(64))).decode("ascii")
APPCAST_URL = "https://update.example.com/appcast.xml?channel=beta"


def appcast(
    *,
    build: str = "920",
    display_version: str = "9.2.0",
    os_name: str = "macos",
    url: str = "https://example.com/lantern-installer-beta.dmg",
    length: str = "12345",
    signature: str = SIGNATURE,
) -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="{resolver.SPARKLE_NS}">
  <channel>
    <item>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{display_version}</sparkle:shortVersionString>
      <enclosure url="{url}" sparkle:os="{os_name}" length="{length}"
                 sparkle:edSignature="{signature}" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
""".encode()


class ResolveDesktopUpdateTargetTest(unittest.TestCase):
    def test_parse_target_accepts_signed_numeric_macos_release(self) -> None:
        target = resolver.parse_target(appcast(), APPCAST_URL, "macos")

        self.assertEqual(target.platform, "macos")
        self.assertEqual(target.target_build, 920)
        self.assertEqual(target.fixture_build, 919)
        self.assertEqual(target.display_version, "9.2.0")
        self.assertEqual(target.fixture_pubspec_version, "9.2.0+919")
        self.assertEqual(target.ed_signature, SIGNATURE)

    def test_parse_target_accepts_signed_numeric_windows_release(self) -> None:
        target = resolver.parse_target(
            appcast(
                os_name="windows",
                url="https://example.com/lantern-installer-beta.exe",
            ),
            APPCAST_URL,
            "windows",
        )

        self.assertEqual(target.platform, "windows")
        self.assertEqual(target.artifact_url, "https://example.com/lantern-installer-beta.exe")
        self.assertEqual(target.artifact_length, 12345)
        self.assertEqual(target.ed_signature, SIGNATURE)

    def test_parse_target_rejects_non_numeric_sparkle_version(self) -> None:
        with self.assertRaises(resolver.TargetError) as raised:
            resolver.parse_target(appcast(build="9.2.0-beta"), APPCAST_URL, "macos")
        self.assertEqual(
            str(raised.exception),
            "appcast Sparkle version must be numeric; got '9.2.0-beta'",
        )

    def test_parse_target_requires_display_version(self) -> None:
        with self.assertRaisesRegex(resolver.TargetError, "display version"):
            resolver.parse_target(appcast(display_version=""), APPCAST_URL, "macos")
        with self.assertRaisesRegex(resolver.TargetError, "display version"):
            resolver.parse_target(
                appcast(display_version="9.2.0+metadata"),
                APPCAST_URL,
                "macos",
            )

    def test_parse_target_requires_macos_dmg(self) -> None:
        with self.assertRaisesRegex(resolver.TargetError, "no macOS enclosure"):
            resolver.parse_target(appcast(os_name="windows"), APPCAST_URL, "macos")

        with self.assertRaisesRegex(resolver.TargetError, "point to a DMG"):
            resolver.parse_target(
                appcast(url="https://example.com/lantern.exe"),
                APPCAST_URL,
                "macos",
            )

    def test_parse_target_requires_https(self) -> None:
        with self.assertRaisesRegex(resolver.TargetError, "must use HTTPS"):
            resolver.parse_target(
                appcast(url="http://example.com/lantern.dmg"),
                APPCAST_URL,
                "macos",
            )

    def test_parse_target_requires_valid_signature(self) -> None:
        signatures = (
            "",
            "not-base64",
            base64.b64encode(b"short").decode("ascii"),
        )
        for signature in signatures:
            with self.subTest(signature=signature):
                with self.assertRaisesRegex(resolver.TargetError, "signature"):
                    resolver.parse_target(appcast(signature=signature), APPCAST_URL, "macos")

    def test_parse_target_rejects_unsafe_xml(self) -> None:
        xml_data = appcast().replace(
            b'<rss version="2.0"',
            b'<!DOCTYPE rss [<!ENTITY build "920">]><rss version="2.0"',
        ).replace(b">920<", b">&build;<")
        with self.assertRaisesRegex(resolver.TargetError, "unsafe appcast"):
            resolver.parse_target(xml_data, APPCAST_URL, "macos")

    def test_write_fixture_pubspec_only_replaces_version(self) -> None:
        target = resolver.parse_target(appcast(), APPCAST_URL, "macos")
        with tempfile.TemporaryDirectory() as tmp:
            source = pathlib.Path(tmp) / "source.yaml"
            destination = pathlib.Path(tmp) / "pubspec.yaml"
            source.write_text("name: lantern\nversion: 1.0.0+1\ndescription: Test\n")

            resolver.write_fixture_pubspec(source, destination, target)

            self.assertEqual(
                destination.read_text(),
                "name: lantern\nversion: 9.2.0+919\ndescription: Test\n",
            )


if __name__ == "__main__":
    unittest.main()
