import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import render_windows_installer_fixture as fixture

ROOT = Path(__file__).resolve().parents[2]


class FixtureRendererTest(unittest.TestCase):
    def test_duplicate_or_missing_substitutions_fail(self):
        for text in ("", "guard\nguard"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                fixture.replace_once(r"^guard$", "stub", text, "guard")

    def test_production_guards_and_lifecycle_are_preserved(self):
        source = (ROOT / "windows/packaging/exe/inno_setup.iss").read_text(encoding="utf-8")
        result = fixture.render_fixture(source, Path("payload"), Path("fixture-dependency.exe"))
        self.assertNotIn("{%", result)
        self.assertNotIn("{{", result)
        self.assertIn('AppId=' + fixture.FIXTURE_APP_ID, result)
        self.assertIn('AppName=' + fixture.FIXTURE_APP_NAME, result)
        self.assertIn('"' + fixture.FIXTURE_SERVICE_NAME + '"', result)
        self.assertIn('#define ServiceInstallDir "C:\\Program Files\\' + fixture.FIXTURE_APP_NAME + '"', result)
        self.assertIn('DefaultDirName={#DefaultInstallDir}', result)
        self.assertIn('Name: "english"; MessagesFile: "compiler:Default.isl"', result)
        self.assertNotIn('Name: "farsi"', result)
        self.assertIn('Flags: checkedonce', result)
        self.assertNotIn("aka.ms/vs/17/release", result)
        # Only the prerequisite registration procedures may change in this section.
        self.assertEqual(
            result.split("procedure Dependency_AddVC2015To2022;", 1)[0],
            source.split("procedure Dependency_AddVC2015To2022;", 1)[0],
        )
        self.assertEqual(
            result.rsplit("[Code]", 1)[1],
            source.rsplit("[Code]", 1)[1].replace("{{EXECUTABLE_NAME}}", "lantern.exe"),
        )

    def test_copy_failure_changes_only_file_manifest(self):
        source = (ROOT / "windows/packaging/exe/inno_setup.iss").read_text(encoding="utf-8")
        rendered = fixture.render_fixture(source, Path("payload"), Path("fixture-dependency.exe"))
        failure = fixture.render_fixture(
            source, Path("payload"), Path("fixture-dependency.exe"), fail_file_copy=True
        )
        injected = 'Source: "{tmp}\\fixture-intentionally-missing.bin"; DestDir: "{app}"; ExternalSize: 1; Flags: external ignoreversion\n\n'
        self.assertEqual(failure.count(injected), 1)
        self.assertEqual(failure.replace(injected, ""), rendered)


if __name__ == "__main__":
    unittest.main()
