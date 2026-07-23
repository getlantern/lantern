#!/usr/bin/env python3

from __future__ import annotations

import json
import pathlib
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import verify_update_service


class UpdateServiceHandler(BaseHTTPRequestHandler):
    beta_version = "9.2.0-beta"
    stable_version = "9.1.0"
    stable_appcast_status = 200
    beta_enclosures = [
        ("macos", "macos-signature", "https://example.com/lantern-installer-beta.dmg"),
        ("windows", "windows-signature", "https://example.com/lantern-installer-beta.exe"),
    ]
    post_count = 0
    get_count = 0

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API.
        self.__class__.post_count += 1
        length = int(self.headers["Content-Length"])
        body = json.loads(self.rfile.read(length))
        tags = body.get("tags", {})
        channel = tags.get("channel", "stable")
        os_name = tags.get("os", "android")
        suffix = ".deb" if os_name == "linux" else ".apk"

        if channel == "beta":
            self.write_json(
                {
                    "version": self.beta_version,
                    "url": f"https://example.com/lantern-installer-beta{suffix}",
                    "checksum": "a" * 64,
                }
            )
            return

        self.write_json(
            {
                "version": self.stable_version,
                "url": f"https://example.com/lantern-installer{suffix}",
                "checksum": "b" * 64,
            }
        )

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API.
        self.__class__.get_count += 1
        if self.path.endswith("channel=beta"):
            self.write_xml(
                self.appcast_xml(
                    self.beta_version,
                    self.beta_enclosures,
                )
            )
            return
        if self.stable_appcast_status == 404:
            self.send_response(404)
            self.end_headers()
            return
        self.write_xml(
            self.appcast_xml(
                self.stable_version,
                [
                    ("macos", "macos-signature", "https://example.com/lantern-installer.dmg"),
                    ("windows", "windows-signature", "https://example.com/lantern-installer.exe"),
                ],
            )
        )

    def log_message(self, format: str, *args: Any) -> None:
        return

    def write_json(self, data: dict[str, str]) -> None:
        encoded = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def write_xml(self, data: str) -> None:
        encoded = data.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/xml")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    @staticmethod
    def appcast_xml(version: str, enclosures: list[tuple[str, str, str]]) -> str:
        enclosure_xml = "\n".join(
            f'<enclosure url="{url}" sparkle:edSignature="{signature}" sparkle:os="{os_name}" '
            'length="12" type="application/octet-stream"/>'
            for os_name, signature, url in enclosures
        )
        return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <sparkle:version>{version}</sparkle:version>
      {enclosure_xml}
    </item>
  </channel>
</rss>
"""


class VerifyUpdateServiceTest(unittest.TestCase):
    def setUp(self) -> None:
        UpdateServiceHandler.stable_appcast_status = 200
        UpdateServiceHandler.beta_enclosures = [
            ("macos", "macos-signature", "https://example.com/lantern-installer-beta.dmg"),
            ("windows", "windows-signature", "https://example.com/lantern-installer-beta.exe"),
        ]
        UpdateServiceHandler.post_count = 0
        UpdateServiceHandler.get_count = 0
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), UpdateServiceHandler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.update_url = f"http://127.0.0.1:{self.server.server_port}/update/lantern"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()

    def test_run_checks_once_accepts_valid_beta_release(self) -> None:
        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("all"),
            )
        )

    def test_run_checks_once_accepts_missing_stable_appcast(self) -> None:
        UpdateServiceHandler.stable_appcast_status = 404

        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("all"),
            )
        )

    def test_run_checks_once_accepts_single_platform_appcast_release(self) -> None:
        UpdateServiceHandler.beta_enclosures = [
            ("macos", "macos-signature", "https://example.com/lantern-installer-beta.dmg"),
        ]

        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("macos"),
            )
        )

    def test_run_checks_once_skips_appcast_for_android_only_release(self) -> None:
        UpdateServiceHandler.stable_appcast_status = 404

        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("android"),
            )
        )

        self.assertEqual(UpdateServiceHandler.get_count, 0)
        self.assertEqual(UpdateServiceHandler.post_count, 2)

    def test_run_checks_once_accepts_linux_only_release(self) -> None:
        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("linux"),
            )
        )

    def test_run_checks_once_skips_ios_only_release(self) -> None:
        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("ios"),
            )
        )

        self.assertEqual(UpdateServiceHandler.get_count, 0)
        self.assertEqual(UpdateServiceHandler.post_count, 0)

    def test_normalize_platforms_rejects_unknown_platforms(self) -> None:
        with self.assertRaises(verify_update_service.VerificationError):
            verify_update_service.normalize_platforms("android,beos")

    def test_parse_appcast_preserves_empty_signature(self) -> None:
        xml_text = UpdateServiceHandler.appcast_xml(
            "9.2.0-beta",
            [("macos", "", "https://example.com/lantern-installer-beta.dmg")],
        )
        version, enclosures = verify_update_service.parse_appcast(xml_text)
        self.assertEqual(version, "9.2.0-beta")
        self.assertEqual(enclosures[0]["signature"], "")

    def test_parse_appcast_rejects_internal_entities(self) -> None:
        xml_text = """<?xml version="1.0"?>
<!DOCTYPE rss [<!ENTITY version "9.2.0-beta">]>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <sparkle:version>&version;</sparkle:version>
      <enclosure url="https://example.com/lantern.dmg"
                 sparkle:edSignature="signature"
                 sparkle:os="macos"/>
    </item>
  </channel>
</rss>
"""
        with self.assertRaisesRegex(
            verify_update_service.VerificationError,
            "unsafe appcast XML",
        ):
            verify_update_service.parse_appcast(xml_text)


if __name__ == "__main__":
    unittest.main()
