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
    beta_appcast_version = "9.2.0-beta"
    stable_version = "9.1.0"
    stable_appcast_version = "9.1.0"
    linux_arm64_version = ""
    requests = []
    stable_appcast_status = 200
    beta_enclosures = [
        ("macos", "macos-signature", "https://example.com/lantern-installer-beta.dmg"),
        ("windows", "windows-signature", "https://example.com/lantern-installer-beta.exe"),
    ]
    post_count = 0
    get_count = 0
    forced_post_status = 0
    forced_get_status = 0
    transient_post_failures = 0

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API.
        self.__class__.post_count += 1
        if self.headers.get("User-Agent") != "LanternUpdateVerifier/1.0":
            self.send_error(403, "error 1010")
            return
        if self.__class__.forced_post_status:
            self.send_error(self.__class__.forced_post_status)
            return
        if self.__class__.transient_post_failures > 0:
            self.__class__.transient_post_failures -= 1
            self.send_error(503)
            return
        length = int(self.headers["Content-Length"])
        body = json.loads(self.rfile.read(length))
        tags = body.get("tags", {})
        self.requests.append(tags)
        channel = tags.get("channel", "stable")
        os_name = tags.get("os", "android")
        if os_name != "android" and not body.get("checksum"):
            self.send_error(417, "checksum must not be nil")
            return
        suffix = ".deb" if os_name == "linux" else ".apk"
        if os_name == "linux" and tags.get("arch") == "arm64":
            suffix = "-arm64.deb"

        if channel == "beta":
            self.write_json(
                {
                    "version": (self.linux_arm64_version or self.beta_version)
                    if suffix == "-arm64.deb" else self.beta_version,
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
        if self.headers.get("User-Agent") != "LanternUpdateVerifier/1.0":
            self.send_error(403, "error 1010")
            return
        if self.__class__.forced_get_status:
            self.send_error(self.__class__.forced_get_status)
            return
        if self.path.endswith("channel=beta"):
            self.write_xml(
                self.appcast_xml(
                    self.beta_appcast_version,
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
                self.stable_appcast_version,
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
            f'<enclosure url="{url}" '
            f'sparkle:edSignature="{signature}" '
            f'sparkle:os="{os_name}" '
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
        UpdateServiceHandler.stable_version = "9.1.0"
        UpdateServiceHandler.stable_appcast_version = "9.1.0"
        UpdateServiceHandler.linux_arm64_version = ""
        UpdateServiceHandler.requests = []
        UpdateServiceHandler.beta_appcast_version = UpdateServiceHandler.beta_version
        UpdateServiceHandler.beta_enclosures = [
            ("macos", "macos-signature", "https://example.com/lantern-installer-beta.dmg"),
            ("windows", "windows-signature", "https://example.com/lantern-installer-beta.exe"),
        ]
        UpdateServiceHandler.post_count = 0
        UpdateServiceHandler.get_count = 0
        UpdateServiceHandler.forced_post_status = 0
        UpdateServiceHandler.forced_get_status = 0
        UpdateServiceHandler.transient_post_failures = 0
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), UpdateServiceHandler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.update_url = f"http://127.0.0.1:{self.server.server_port}/update/lantern"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()

    def poll_config(
        self,
        platforms: str = "android",
        sparkle_version: str = "",
        timeout_seconds: int = 5,
    ) -> verify_update_service.Config:
        return verify_update_service.Config(
            update_url=self.update_url,
            channel="beta",
            version="v9.2.0-beta",
            timeout_seconds=timeout_seconds,
            interval_seconds=1,
            platforms=verify_update_service.normalize_platforms(platforms),
            sparkle_version=sparkle_version,
        )

    def assert_fails_fast(self, expected_hint: str) -> None:
        with self.assertRaises(SystemExit) as caught:
            verify_update_service.poll_until_verified(self.poll_config())

        self.assertIn("not retrying", str(caught.exception))
        self.assertIn(expected_hint, str(caught.exception))
        # A retry would have issued a second request against the same failure.
        self.assertEqual(UpdateServiceHandler.post_count, 1)

    def test_run_checks_once_accepts_valid_beta_release(self) -> None:
        UpdateServiceHandler.beta_appcast_version = "920"
        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="beta",
                version="v9.2.0-beta",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("all"),
                sparkle_version="920",
            )
        )

    def test_run_checks_once_accepts_valid_stable_release(self) -> None:
        UpdateServiceHandler.stable_version = "9.2.0"
        UpdateServiceHandler.stable_appcast_version = "920"
        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url,
                channel="stable",
                version="v9.2.0",
                timeout_seconds=1,
                interval_seconds=1,
                platforms=verify_update_service.normalize_platforms("all"),
                sparkle_version="920",
                asset_base_url="https://example.com",
            )
        )

    def test_run_checks_once_rejects_wrong_promoted_asset_url(self) -> None:
        UpdateServiceHandler.stable_version = "9.2.0"
        with self.assertRaisesRegex(
            verify_update_service.VerificationError,
            "want https://releases.example/9.2.0/lantern-installer.apk",
        ):
            verify_update_service.run_checks_once(
                verify_update_service.Config(
                    update_url=self.update_url,
                    channel="stable",
                    version="9.2.0",
                    timeout_seconds=1,
                    interval_seconds=1,
                    platforms=verify_update_service.normalize_platforms("android"),
                    asset_base_url="https://releases.example/9.2.0",
                )
            )

    def test_appcast_accepts_origin_and_update_server_downloads(self) -> None:
        release_path = "/releases/beta/9.2.0-beta"
        endpoint = self.update_url.removesuffix("/update/lantern")
        for host in ("s3.amazonaws.com", "s3.us-east-1.amazonaws.com"):
            origin = f"https://{host}/lantern.io{release_path}"
            for base in (origin, endpoint + release_path):
                with self.subTest(base=base):
                    UpdateServiceHandler.beta_enclosures = [
                        (os_name, "signature", f"{base}/lantern-installer-beta{suffix}")
                        for os_name, suffix in (("macos", ".dmg"), ("windows", ".exe"))
                    ]
                    verify_update_service.verify_appcast_channel(
                        self.update_url, "9.2.0-beta", frozenset({"macos", "windows"}),
                        "beta", origin,
                    )

    def test_appcast_rejects_other_hosts_and_release_objects(self) -> None:
        endpoint = self.update_url.removesuffix("/update/lantern")
        release_path = "/releases/beta/9.2.0-beta"
        origin = f"https://s3.amazonaws.com/lantern.io{release_path}"
        for base in (
            "https://other.example" + release_path,
            endpoint + "/releases/beta/9.1.0-beta",
            endpoint + "/releases/beta/latest",
            endpoint + "/releases/production/9.2.0-beta",
        ):
            with self.subTest(base=base):
                UpdateServiceHandler.beta_enclosures = [
                    ("windows", "signature", base + "/lantern-installer-beta.exe"),
                ]
                with self.assertRaisesRegex(verify_update_service.VerificationError, "returned URL"):
                    verify_update_service.verify_appcast_channel(
                        self.update_url, "9.2.0-beta", frozenset({"windows"}), "beta", origin,
                    )

    def test_appcast_does_not_reroute_unrelated_origins(self) -> None:
        for origin in (
            "https://example.com/releases/beta/9.2.0-beta/lantern-installer-beta.exe",
            "https://s3.amazonaws.com/other/releases/beta/9.2.0-beta/lantern-installer-beta.exe",
            "https://s3.amazonaws.com.evil.example/lantern.io/releases/beta/9.2.0-beta/lantern-installer-beta.exe",
        ):
            with self.subTest(origin=origin):
                self.assertEqual(
                    verify_update_service.appcast_download_urls(self.update_url, origin), {origin},
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
                sparkle_version="9.2.0-beta",
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
                sparkle_version="9.2.0-beta",
            )
        )

    def test_run_checks_once_requires_sparkle_version_for_desktop(self) -> None:
        with self.assertRaisesRegex(
            verify_update_service.VerificationError,
            "--sparkle-version is required",
        ):
            verify_update_service.run_checks_once(
                verify_update_service.Config(
                    update_url=self.update_url,
                    channel="beta",
                    version="v9.2.0-beta",
                    timeout_seconds=1,
                    interval_seconds=1,
                    platforms=verify_update_service.normalize_platforms("windows"),
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
                asset_base_url="https://example.com",
            )
        )
        self.assertEqual(
            {(request["arch"], request["channel"]) for request in UpdateServiceHandler.requests},
            {("amd64", "beta"), ("amd64", "stable"), ("arm64", "beta"), ("arm64", "stable")},
        )

    def test_stale_linux_arm64_feed_fails_verification(self) -> None:
        UpdateServiceHandler.linux_arm64_version = "9.1.0-beta"
        with self.assertRaisesRegex(verify_update_service.VerificationError, "returned 9.1.0-beta"):
            verify_update_service.run_checks_once(
                verify_update_service.Config(
                    update_url=self.update_url, channel="beta", version="9.2.0-beta",
                    timeout_seconds=1, interval_seconds=1, platforms=frozenset({"linux"}),
                )
            )

    def test_arm64_only_release_does_not_require_amd64_update(self) -> None:
        verify_update_service.run_checks_once(
            verify_update_service.Config(
                update_url=self.update_url, channel="beta", version="9.2.0-beta",
                timeout_seconds=1, interval_seconds=1, platforms=frozenset({"linux"}),
                linux_arch="arm64", asset_base_url="https://example.com",
            )
        )
        self.assertEqual({request["arch"] for request in UpdateServiceHandler.requests}, {"arm64"})

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

    def test_poll_until_verified_fails_fast_on_blocked_request(self) -> None:
        UpdateServiceHandler.forced_post_status = 403
        self.assert_fails_fast("check the User-Agent")

    def test_poll_until_verified_fails_fast_on_rejected_payload(self) -> None:
        UpdateServiceHandler.forced_post_status = 417
        self.assert_fails_fast("must send a checksum")

    def test_poll_until_verified_fails_fast_on_malformed_request(self) -> None:
        UpdateServiceHandler.forced_post_status = 400
        self.assert_fails_fast("malformed request payload")

    def test_poll_until_verified_fails_fast_on_blocked_appcast(self) -> None:
        UpdateServiceHandler.forced_get_status = 403

        with self.assertRaises(SystemExit) as caught:
            verify_update_service.poll_until_verified(
                self.poll_config(platforms="macos", sparkle_version="9.2.0-beta")
            )

        self.assertIn("not retrying", str(caught.exception))
        self.assertEqual(UpdateServiceHandler.get_count, 1)

    def test_poll_until_verified_retries_server_errors(self) -> None:
        UpdateServiceHandler.transient_post_failures = 1

        verify_update_service.poll_until_verified(self.poll_config(timeout_seconds=30))

        # One rejected request, then both checks on the next attempt.
        self.assertEqual(UpdateServiceHandler.post_count, 3)

    def test_poll_until_verified_retries_while_release_propagates(self) -> None:
        self.addCleanup(
            setattr, UpdateServiceHandler, "beta_version", UpdateServiceHandler.beta_version
        )
        UpdateServiceHandler.beta_version = "9.1.9-beta"

        with self.assertRaises(SystemExit) as caught:
            verify_update_service.poll_until_verified(self.poll_config(timeout_seconds=3))

        self.assertNotIn("not retrying", str(caught.exception))
        self.assertGreater(UpdateServiceHandler.post_count, 1)

    def test_normalize_platforms_rejects_unknown_platforms(self) -> None:
        with self.assertRaises(verify_update_service.VerificationError):
            verify_update_service.normalize_platforms("android,beos")

    def test_normalize_version_accepts_optional_case_insensitive_prefix(self) -> None:
        for version in ("9.2.0-beta", "v9.2.0-beta", "V9.2.0-beta"):
            with self.subTest(version=version):
                self.assertEqual(
                    verify_update_service.normalize_version(version),
                    "9.2.0-beta",
                )

    def test_parse_appcast_preserves_empty_signature(self) -> None:
        xml_text = UpdateServiceHandler.appcast_xml(
            "9.2.0-beta",
            [("macos", "", "https://example.com/lantern-installer-beta.dmg")],
        )
        version, enclosures = verify_update_service.parse_appcast(xml_text)
        self.assertEqual(version, "9.2.0-beta")
        self.assertEqual(enclosures[0]["ed_signature"], "")

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
