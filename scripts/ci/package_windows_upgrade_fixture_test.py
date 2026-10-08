import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).with_name('package_windows_upgrade_fixture.py')
spec = importlib.util.spec_from_file_location('upgrade_fixture', SCRIPT)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class UpgradeFixtureTests(unittest.TestCase):
    def test_fixture_uses_production_installer_identity_and_code(self):
        packaging = fixture.PACKAGING
        original = (packaging / 'inno_setup.iss').read_text(encoding='utf-8')
        config = (packaging / 'make_config.yaml').read_text(encoding='utf-8')
        rendered = fixture.render(original, config, Path(r'C:\Windows app bundle'))
        self.assertIn('AppId=' + fixture.config_value(config, 'app_id'), rendered)
        self.assertIn('AppName=' + fixture.config_value(config, 'display_name'), rendered)
        self.assertIn('AppVersion=0.0.0', rendered)
        self.assertIn('OutputBaseFilename=upgrade-from', rendered)
        self.assertIn('ArchitecturesAllowed=x64compatible', rendered)
        self.assertIn(r'"C:\Windows app bundle"', rendered)
        self.assertIn('IsArm64 and FileExists(Arm64Path)', rendered)
        self.assertIn('Dependency_AddVCRuntime;', rendered)
        self.assertIn('StopAndDeleteService;', rendered)
        self.assertNotIn('{{', rendered)
        self.assertNotIn('{%', rendered)

    def test_new_template_syntax_is_rejected(self):
        config = (fixture.PACKAGING / 'make_config.yaml').read_text(encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Unrendered'):
            fixture.render('{% if NEW_FLAG %}unknown{% endif %}', config, Path('bundle'))

    def test_missing_packaging_identity_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Missing packaging setting: app_id'):
            fixture.render('AppId={{APP_ID}}', 'display_name: Lantern', Path('bundle'))


if __name__ == '__main__':
    unittest.main()
