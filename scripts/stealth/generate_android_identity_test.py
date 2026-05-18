#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_android_identity as generator


class AndroidIdentityGeneratorTest(unittest.TestCase):
    def test_seeded_generation_is_deterministic(self) -> None:
        first = generator.generate_identity(seed="release-2026-05-15")
        second = generator.generate_identity(seed="release-2026-05-15")

        self.assertEqual(first, second)
        self.assertNotEqual(first.application_id, "org.getlantern.lantern")
        self.assertNotIn("Lantern", first.app_label)
        self.assertNotIn("VPN", first.notification_connected_text)
        self.assertIn(first.app_label, first.notification_connected_text)
        self.assertIn(first.app_label, first.quick_tile_active_label)
        self.assertEqual(first.quick_tile_icon, "@drawable/neutral_notification_icon")
        self.assertRegex(
            first.application_id,
            re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$"),
        )

    def test_different_seeds_generate_different_install_identities(self) -> None:
        first = generator.generate_identity(seed="one")
        second = generator.generate_identity(seed="two")

        self.assertNotEqual(first.application_id, second.application_id)
        self.assertNotEqual(first.identity_profile_id, second.identity_profile_id)
        self.assertNotEqual(first.notification_connected_text, second.notification_connected_text)
        self.assertNotEqual(first.quick_tile_active_label, second.quick_tile_active_label)

    def test_random_generation_changes_identity(self) -> None:
        first = generator.generate_identity()
        second = generator.generate_identity()

        self.assertNotEqual(first.application_id, second.application_id)
        self.assertNotEqual(first.identity_profile_id, second.identity_profile_id)

    def test_writes_gradle_properties_profile(self) -> None:
        identity = generator.generate_identity(seed="properties")

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "identity.properties"
            generator.write_properties(identity, output)
            content = output.read_text(encoding="utf-8")

        self.assertIn(f"applicationId={identity.application_id}", content)
        self.assertIn(f"appLabel={identity.app_label}", content)
        self.assertIn(f"quickTileIcon={identity.quick_tile_icon}", content)
        metadata_line = next(
            line for line in content.splitlines() if line.startswith("identityMetadata=")
        )
        metadata = json.loads(metadata_line.split("=", 1)[1])
        self.assertEqual(metadata["generator"], "android-identity-v1")
        self.assertNotIn("stealth", metadata["generator"])
        self.assertEqual(metadata["profileId"], identity.identity_profile_id)
        self.assertEqual(metadata["randomSeed"], False)


if __name__ == "__main__":
    unittest.main()
