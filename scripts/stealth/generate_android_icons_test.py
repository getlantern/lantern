import hashlib
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_android_icons


class GenerateAndroidIconsTest(unittest.TestCase):
    def test_generates_expected_resource_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "res"

            metadata = generate_android_icons.generate("variant-a", out)

            self.assertEqual(metadata["launcherIcon"], "@mipmap/ic_launcher_alt")
            self.assertTrue((out / "values/icon_colors_alt.xml").exists())
            self.assertTrue((out / "drawable/launcher_foreground_alt.xml").exists())
            self.assertTrue((out / "drawable/launcher_monochrome_alt.xml").exists())
            self.assertTrue((out / "drawable/ic_notification_alt.xml").exists())
            self.assertNotIn(
                "#00000000",
                self.read(out, "drawable/launcher_foreground_alt.xml"),
            )
            self.assertIn(
                '@drawable/launcher_monochrome_alt',
                self.read(out, "mipmap-anydpi-v26/ic_launcher_alt.xml"),
            )
            self.assertNotIn(
                "#00000000",
                self.read(out, "drawable/ic_notification_alt.xml"),
            )
            # No "stealth" token in any generated resource name
            for f in out.rglob("*"):
                self.assertNotIn("stealth", f.name.lower())
            self.assertTrue((out / "mipmap-anydpi/ic_launcher_alt.xml").exists())
            self.assertTrue(
                (out / "mipmap-anydpi/ic_launcher_alt_round.xml").exists()
            )
            self.assertTrue((out / "mipmap-anydpi-v26/ic_launcher_alt.xml").exists())
            self.assertTrue(
                (out / "mipmap-anydpi-v26/ic_launcher_alt_round.xml").exists()
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
                (first / "drawable/launcher_foreground_alt.xml").read_text(),
                (second / "drawable/launcher_foreground_alt.xml").read_text(),
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
                (first / "drawable/launcher_foreground_alt.xml").read_text(),
                (second / "drawable/launcher_foreground_alt.xml").read_text(),
            )

    def test_main_reads_seed_from_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "res"

            with patch.dict("os.environ", {"STEALTH_ICON_SEED": "variant-env"}):
                with redirect_stdout(StringIO()):
                    exit_code = generate_android_icons.main(
                        ["--output-res-dir", str(out)]
                    )

            expected_sha = hashlib.sha256(b"variant-env").hexdigest()
            metadata = (out.parent / "stealth-icon-metadata.json").read_text()
            self.assertEqual(exit_code, 0)
            self.assertIn(expected_sha, metadata)

    def read(self, root: Path, relative_path: str) -> str:
        return (root / relative_path).read_text(encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
