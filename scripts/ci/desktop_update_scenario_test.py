#!/usr/bin/env python3

import contextlib
import io
import json
import os
from pathlib import Path
import socket
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import desktop_update_scenario as scenario


def target(name="core-unavailable-direct-blocked"):
    return {
        "appcast_url": (
            scenario.PRODUCTION_FEED
            if name == scenario.SCENARIOS[2]
            else scenario.STAGING_FEED
        ),
        "artifact_url": "https://s3.amazonaws.com/lantern.io/releases/9.2.0/lantern-beta.dmg",
        "fixture_build": 919,
        "display_version": "9.2.0",
    }


def handoff(name="core-unavailable-direct-blocked"):
    return {
        "scenario": name,
        "feed_url": target(name)["appcast_url"],
        "build_number": "919",
        "display_version": "9.2.0",
        "pid": 1234,
        "update_offered": True,
        "core_initialization_held": name != "baseline",
        "core_ready": name == "baseline",
    }


class DesktopUpdateScenarioTest(unittest.TestCase):
    def test_block_and_restore_preserve_existing_hosts_and_file(self):
        for newline in (b"\n", b"\r\n"):
            with self.subTest(newline=newline), tempfile.TemporaryDirectory() as tmp:
                hosts = Path(tmp) / "hosts"
                original = newline.join(
                    (
                        b"# local entries",
                        b"127.0.0.1 localhost",
                        b"192.0.2.1 internal.example",
                        b"",
                    )
                )
                hosts.write_bytes(original)
                hosts.chmod(0o640)
                before = hosts.stat()
                scenario.edit_hosts(hosts, True)
                blocked = hosts.read_bytes()
                self.assertTrue(blocked.startswith(original))
                for host in scenario.BLOCKED_HOSTS:
                    for address in ("127.0.0.1", "::1"):
                        self.assertIn(
                            f"{address} {host} {scenario.MARKER}\n".encode(), blocked
                        )
                scenario.edit_hosts(hosts, True)
                self.assertEqual(hosts.read_bytes(), blocked)
                scenario.edit_hosts(hosts, False)
                scenario.edit_hosts(hosts, False)
                self.assertEqual(hosts.read_bytes(), original)
                self.assertEqual(hosts.stat().st_ino, before.st_ino)
                self.assertEqual(hosts.stat().st_mode, before.st_mode)

    def test_hosts_without_final_newline_get_separate_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            hosts = Path(tmp) / "hosts"
            hosts.write_text("127.0.0.1 localhost")
            scenario.edit_hosts(hosts, True)
            self.assertTrue(
                hosts.read_text().startswith("127.0.0.1 localhost\n127.0.0.1 update.")
            )
            scenario.edit_hosts(hosts, False)
            self.assertEqual(hosts.read_text(), "127.0.0.1 localhost\n")

    def test_dns_requires_every_address_to_be_loopback(self):
        loopback = [
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443)),
            (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("::1", 443, 0, 0)),
        ]
        with mock.patch.object(socket, "getaddrinfo", return_value=loopback):
            resolved = scenario.require_blocked_dns()
            self.assertEqual(set(resolved), set(scenario.BLOCKED_HOSTS))
        for addresses in (
            [],
            loopback
            + [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("192.0.2.1", 443))],
        ):
            with self.subTest(addresses=addresses), mock.patch.object(
                socket, "getaddrinfo", return_value=addresses
            ):
                with self.assertRaisesRegex(ValueError, "Direct access is not blocked"):
                    scenario.require_blocked_dns()

    def test_target_feed_matches_scenario(self):
        for name in scenario.SCENARIOS:
            scenario.validate_target(name, target(name))
            wrong = dict(target(name), appcast_url="https://example.com/appcast.xml")
            with self.subTest(name=name), self.assertRaisesRegex(
                ValueError, "requires"
            ):
                scenario.validate_target(name, wrong)
        with self.assertRaisesRegex(ValueError, "Unknown"):
            scenario.validate_target("typo", target())

    def test_blocked_installer_must_use_supported_release_route(self):
        for host, prefix in (
            ("update.getlantern.org", "/releases/"),
            ("s3.amazonaws.com", "/lantern.io/releases/"),
            ("s3.us-east-1.amazonaws.com", "/lantern.io/releases/"),
        ):
            for extension in ("dmg", "exe"):
                scenario.validate_target(
                    scenario.SCENARIOS[2],
                    dict(
                        target(),
                        artifact_url=f"https://{host}{prefix}9.2.0/lantern.{extension}",
                    ),
                )
        for url in (
            "https://github.com/getlantern/lantern-update-fixtures/releases/download/fixture/lantern.dmg",
            "https://s3.amazonaws.com/other-bucket/releases/lantern.dmg",
            "https://update.getlantern.org/lantern.dmg",
            "https://update.getlantern.org/releases/../lantern.dmg",
            "https://update.getlantern.org/releases/%2e%2e/lantern.dmg",
            "https://update.getlantern.org/releases/lantern.zip",
            "http://update.getlantern.org/releases/lantern.dmg",
            "https://user@update.getlantern.org/releases/lantern.dmg",
            "https://update.getlantern.org/releases/lantern.dmg?redirect=s3",
        ):
            with self.subTest(url=url), self.assertRaisesRegex(
                ValueError, "published beta installer"
            ):
                scenario.validate_target(
                    scenario.SCENARIOS[2], dict(target(), artifact_url=url)
                )

    def test_handoff_proves_update_offer_before_core_readiness(self):
        for name in scenario.SCENARIOS:
            scenario.verify_handoff(name, target(name), handoff(name))
        for key, value in (
            ("scenario", "baseline"),
            ("feed_url", scenario.STAGING_FEED),
            ("build_number", "918"),
            ("display_version", "9.1.0"),
            ("update_offered", False),
            ("update_offered", 1),
            ("core_initialization_held", False),
            ("core_ready", True),
            ("core_ready", 0),
            ("pid", 0),
            ("pid", True),
        ):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                scenario.verify_handoff(
                    scenario.SCENARIOS[2], target(), dict(handoff(), **{key: value})
                )
        for key in handoff():
            incomplete = handoff()
            del incomplete[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                scenario.verify_handoff(scenario.SCENARIOS[2], target(), incomplete)

    def test_network_commands_require_ci_guard(self):
        for command in ("block", "restore"):
            with mock.patch.dict(os.environ, {}, clear=True), mock.patch.object(
                sys, "argv", ["scenario", command]
            ), contextlib.redirect_stderr(io.StringIO()):
                with mock.patch.object(scenario, "edit_hosts") as edit:
                    with self.assertRaises(SystemExit) as raised:
                        scenario.main()
                    self.assertEqual(raised.exception.code, 2)
                    edit.assert_not_called()

    def test_macos_network_commands_require_self_hosted_runner(self):
        env = dict(CI="true", GITHUB_ACTIONS="true", LANTERN_AUTO_UPDATE_SMOKE="true")
        with mock.patch.dict(os.environ, env, clear=True), mock.patch.object(
            sys, "platform", "darwin"
        ), mock.patch.object(
            sys, "argv", ["scenario", "restore"]
        ), contextlib.redirect_stderr(
            io.StringIO()
        ):
            with mock.patch.object(scenario, "edit_hosts") as edit:
                with self.assertRaises(SystemExit):
                    scenario.main()
                edit.assert_not_called()

    def test_prepare_and_verify_write_scenario_evidence(self):
        env = dict(CI="true", GITHUB_ACTIONS="true", LANTERN_AUTO_UPDATE_SMOKE="true")
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, env):
            root = Path(tmp)
            (root / "target.json").write_text(
                json.dumps(target("core-unavailable")), encoding="utf-8-sig"
            )
            (root / "handoff.json").write_text(json.dumps(handoff("core-unavailable")))
            for command in ("prepare", "verify"):
                args = [
                    "scenario",
                    command,
                    "--scenario",
                    "core-unavailable",
                    "--target",
                    str(root / "target.json"),
                    "--handoff",
                    str(root / "handoff.json"),
                    "--output",
                    str(root / "evidence.json"),
                ]
                with mock.patch.object(sys, "argv", args):
                    scenario.main()
                evidence = json.loads((root / "evidence.json").read_text())
                self.assertEqual(evidence["scenario"], "core-unavailable")
                self.assertEqual(evidence["appcast_url"], scenario.STAGING_FEED)
                if command == "verify":
                    self.assertEqual(evidence["handoff"], handoff("core-unavailable"))


if __name__ == "__main__":
    unittest.main()
