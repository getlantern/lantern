#!/usr/bin/env python3

import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
import unittest.mock as mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import desktop_update_scenario as scenario


def target():
    return {
        "appcast_url": scenario.STAGING_FEED,
        "fixture_build": 919,
        "display_version": "9.2.0",
    }


def handoff(name="core-unavailable"):
    return {
        "scenario": name,
        "feed_url": target()["appcast_url"],
        "build_number": "919",
        "display_version": "9.2.0",
        "pid": 1234,
        "update_offered": True,
        "core_initialization_held": name != "baseline",
        "core_ready": name == "baseline",
    }


class DesktopUpdateScenarioTest(unittest.TestCase):
    def test_target_feed_matches_scenario(self):
        for name in scenario.SCENARIOS:
            scenario.validate_target(name, target())
            wrong = dict(target(), appcast_url="https://example.com/appcast.xml")
            with self.subTest(name=name), self.assertRaisesRegex(
                ValueError, "requires"
            ):
                scenario.validate_target(name, wrong)
        with self.assertRaisesRegex(ValueError, "Unknown"):
            scenario.validate_target("typo", target())

    def test_handoff_proves_update_offer_before_core_readiness(self):
        for name in scenario.SCENARIOS:
            scenario.verify_handoff(name, target(), handoff(name))
        for key, value in (
            ("scenario", "baseline"),
            ("feed_url", "https://example.com/appcast.xml"),
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
                    "core-unavailable", target(), dict(handoff(), **{key: value})
                )
        for key in handoff():
            incomplete = handoff()
            del incomplete[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                scenario.verify_handoff("core-unavailable", target(), incomplete)

    def test_commands_require_ci_guard(self):
        for command in ("prepare", "verify"):
            with mock.patch.dict(os.environ, {}, clear=True), mock.patch.object(
                sys, "argv", ["scenario", command]
            ), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as raised:
                    scenario.main()
                self.assertEqual(raised.exception.code, 2)

    def test_prepare_and_verify_write_scenario_evidence(self):
        env = dict(CI="true", GITHUB_ACTIONS="true", LANTERN_AUTO_UPDATE_SMOKE="true")
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, env):
            root = Path(tmp)
            (root / "target.json").write_text(
                json.dumps(target()), encoding="utf-8-sig"
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
