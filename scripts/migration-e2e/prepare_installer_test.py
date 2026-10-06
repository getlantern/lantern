from pathlib import Path
import unittest

import prepare_installer as installer


class InstallerEnvironmentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.template = (Path(__file__).resolve().parents[2] / "windows/packaging/exe/inno_setup.iss").read_text()

    def test_production_template_remains_byte_identical(self):
        self.assertEqual(self.template, installer.render(self.template, "prod", False, "production", False))
        self.assertEqual(self.template, installer.render(self.template, "prod", False, "nightly", True))

    def test_staging_changes_only_the_two_service_commands(self):
        rendered = installer.render(self.template, "staging", True, "migration-e2e", True)
        self.assertEqual(rendered.count("install --environment staging"), 2)
        self.assertEqual(rendered.replace("install --environment staging", "install"), self.template)
        self.assertIn("prepare-legacy-migration --sid", rendered)

    def test_all_staging_guards_required(self):
        for args in (("staging", False, "migration-e2e", True), ("staging", True, "production", True),
                     ("staging", True, " PRODUCTION ", True), ("staging", True, "migration-e2e", False),
                     ("prod", True, "migration-e2e", True), ("invalid", True, "migration-e2e", True)):
            with self.subTest(args=args), self.assertRaises(ValueError):
                installer.validate(*args)

    def test_missing_duplicate_or_changed_site_fails_closed(self):
        for changed in (self.template.replace(installer.ORDINARY_INSTALL, ""),
                        self.template + "\n" + installer.MIGRATION_INSTALL,
                        self.template.replace(installer.MIGRATION_INSTALL, installer.MIGRATION_INSTALL.replace("SW_HIDE", "SW_SHOW")),
                        self.template + "\ninstall --environment staging"):
            with self.assertRaises(ValueError):
                installer.render(changed, "staging", True, "migration-e2e", True)

    def test_workflow_passes_environment_to_initial_build_and_packaging(self):
        text = (Path(__file__).resolve().parents[2] / ".github/workflows/build-windows.yml").read_text()
        self.assertIn("RADIANCE_ENV: ${{ inputs.backend_environment == 'staging' && 'staging' || '' }}", text)
        self.assertIn("--build-dart-define=RADIANCE_ENV=staging", text)
        self.assertIn("--build-dart-define=AUTO_UPDATE_E2E=true", text)
        self.assertLess(text.index("Validate backend environment isolation"), text.index("Decode APP_ENV"))
        self.assertLess(text.index("Render staging migration service commands"), text.index("      - name: Package installer"))


if __name__ == "__main__":
    unittest.main()
