import tempfile
import unittest
from pathlib import Path

import generate_android_icons


class GenerateAndroidIconsTest(unittest.TestCase):
    def test_generates_expected_resource_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "res"

            metadata = generate_android_icons.generate("variant-a", out)

            self.assertEqual(metadata["launcherIcon"], "@mipmap/stealth_ic_launcher")
            self.assertTrue((out / "values/stealth_icon_colors.xml").exists())
            self.assertTrue((out / "drawable/stealth_launcher_foreground.xml").exists())
            self.assertTrue((out / "drawable/stealth_notification_icon.xml").exists())
            self.assertTrue((out / "mipmap-anydpi-v26/stealth_ic_launcher.xml").exists())
            self.assertTrue(
                (out / "mipmap-anydpi-v26/stealth_ic_launcher_round.xml").exists()
            )
            self.assertTrue((out / "stealth-icon-metadata.json").exists())

    def test_generation_is_deterministic_for_same_seed(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "first"
            second = Path(tmp) / "second"

            first_metadata = generate_android_icons.generate("variant-a", first)
            second_metadata = generate_android_icons.generate("variant-a", second)

            self.assertEqual(first_metadata, second_metadata)
            self.assertEqual(
                (first / "drawable/stealth_launcher_foreground.xml").read_text(),
                (second / "drawable/stealth_launcher_foreground.xml").read_text(),
            )

    def test_generation_changes_by_seed(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "first"
            second = Path(tmp) / "second"

            first_metadata = generate_android_icons.generate("variant-a", first)
            second_metadata = generate_android_icons.generate("variant-b", second)

            self.assertNotEqual(
                first_metadata["seedSha256"],
                second_metadata["seedSha256"],
            )
            self.assertNotEqual(
                (first / "drawable/stealth_launcher_foreground.xml").read_text(),
                (second / "drawable/stealth_launcher_foreground.xml").read_text(),
            )


if __name__ == "__main__":
    unittest.main()
