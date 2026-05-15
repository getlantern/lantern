import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

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
            self.assertNotIn(
                "#00000000",
                (out / "drawable/stealth_notification_icon.xml").read_text(),
            )
            self.assertTrue((out / "mipmap-anydpi/stealth_ic_launcher.xml").exists())
            self.assertTrue(
                (out / "mipmap-anydpi/stealth_ic_launcher_round.xml").exists()
            )
            self.assertTrue((out / "mipmap-anydpi-v26/stealth_ic_launcher.xml").exists())
            self.assertTrue(
                (out / "mipmap-anydpi-v26/stealth_ic_launcher_round.xml").exists()
            )
            self.assertFalse((out / "stealth-icon-metadata.json").exists())
            self.assertTrue((out.parent / "stealth-icon-metadata.json").exists())

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

    def test_main_reads_seed_from_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "res"

            with patch.dict("os.environ", {"STEALTH_ICON_SEED": "variant-env"}):
                with redirect_stdout(StringIO()):
                    exit_code = generate_android_icons.main(
                        ["--output-res-dir", str(out)]
                    )

            expected = generate_android_icons.generate("variant-env", Path(tmp) / "expected")
            metadata = (out.parent / "stealth-icon-metadata.json").read_text()
            self.assertEqual(exit_code, 0)
            self.assertIn(expected["seedSha256"], metadata)


if __name__ == "__main__":
    unittest.main()
