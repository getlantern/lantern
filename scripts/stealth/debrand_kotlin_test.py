#!/usr/bin/env python3

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import debrand_kotlin as debrand

REPO_RULES = Path(__file__).resolve().parents[2] / "android/app/proguard-stealth-novpn.pro"


class ProguardRulesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.kotlin_root = self.root / "kotlin"
        self.rules = self.root / "rules.pro"
        self.output = self.root / "out/rules.pro"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write_source(self, relative: str, text: str) -> None:
        path = self.kotlin_root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def test_rewrites_class_names_to_debranded_sources(self) -> None:
        self.write_source(
            "foundation/bridge/service/BackendVpnService.kt",
            "package foundation.bridge.service\n\nopen class BackendVpnService : VpnService()\n",
        )
        self.rules.write_text(
            "-checkdiscard class org.getlantern.lantern.service.LanternVpnService\n",
            encoding="utf-8",
        )

        rc = debrand.generate_proguard_rules(self.rules, self.output, self.kotlin_root)

        self.assertEqual(rc, 0)
        self.assertEqual(
            self.output.read_text(encoding="utf-8"),
            "-checkdiscard class foundation.bridge.service.BackendVpnService\n",
        )

    def test_fails_when_checked_class_has_no_generated_source(self) -> None:
        self.rules.write_text(
            "-checkdiscard class org.getlantern.lantern.service.LanternVpnService\n",
            encoding="utf-8",
        )

        rc = debrand.generate_proguard_rules(self.rules, self.output, self.kotlin_root)

        self.assertEqual(rc, 2)
        self.assertFalse(self.output.exists())

    def test_fails_when_file_does_not_declare_checked_class(self) -> None:
        self.write_source(
            "foundation/bridge/service/BackendVpnService.kt",
            "package foundation.bridge.service\n\nclass Placeholder\n",
        )
        self.rules.write_text(
            "-checkdiscard class org.getlantern.lantern.service.LanternVpnService\n",
            encoding="utf-8",
        )

        rc = debrand.generate_proguard_rules(self.rules, self.output, self.kotlin_root)

        self.assertEqual(rc, 2)
        self.assertFalse(self.output.exists())

    def test_fails_when_class_is_in_another_package(self) -> None:
        self.write_source(
            "foundation/bridge/service/BackendVpnService.kt",
            "package foundation.bridge.other\n\nclass BackendVpnService\n",
        )
        self.rules.write_text(
            "-checkdiscard class org.getlantern.lantern.service.LanternVpnService\n",
            encoding="utf-8",
        )

        self.assertEqual(debrand.generate_proguard_rules(self.rules, self.output, self.kotlin_root), 2)

    def test_checks_nested_classes(self) -> None:
        self.write_source(
            "foundation/bridge/service/BackendVpnService.kt",
            "package foundation.bridge.service\n\nclass BackendVpnService {\n    object Companion\n}\n",
        )
        rule = "-checkdiscard class org.getlantern.lantern.service.LanternVpnService${}\n"
        self.rules.write_text(rule.format("Companion"), encoding="utf-8")
        self.assertEqual(debrand.generate_proguard_rules(self.rules, self.output, self.kotlin_root), 0)
        self.rules.write_text(rule.format("Missing"), encoding="utf-8")
        self.assertEqual(debrand.generate_proguard_rules(self.rules, self.output, self.kotlin_root), 2)

    def test_repo_rules_match_debranded_kotlin(self) -> None:
        source_root = Path(__file__).resolve().parents[2] / "android/app/src/main/kotlin/org/getlantern/lantern"
        self.assertEqual(debrand.generate(source_root, self.kotlin_root / debrand.TARGET_PACKAGE_DIR), 0)

        rc = debrand.generate_proguard_rules(REPO_RULES, self.output, self.kotlin_root)

        self.assertEqual(rc, 0)
        self.assertNotIn("getlantern", self.output.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
