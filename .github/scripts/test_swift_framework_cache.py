import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import swift_framework_cache as cache


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.old_directory = Path.cwd()
        os.chdir(self.directory.name)
        self.addCleanup(os.chdir, self.old_directory)
        for name, contents in {
            'go.mod': 'module example.test/fixture\ngo 1.26.2\n',
            'go.sum': 'dependency checksum', 'Makefile': 'CI binding recipe',
            'lantern-core/mobile/mobile.go': 'package mobile',
            'lantern-core/mobile/mobile_test.go': 'package mobile',
            'lib/main.dart': 'void main() {}',
            'pubspec.yaml': 'version: 1.0.0', 'pubspec.lock': 'dependencies',
            '.github/flutter-version.yaml': 'environment:\n  flutter: "3.41.0"',
            'ios/Podfile': 'source CDN', 'ios/Podfile.lock': 'locked versions',
        }.items():
            self.write(name, contents)
        self.tools = {'target': 'iossimulator/arm64', 'host': 'arm64',
                      'macos': '26.0', 'xcode': 'Xcode 26.6\nBuild version 17F113',
                      'sdk': '23F77', 'go': 'go1.26.2', 'identity': 'swift-check-v1'}

    def write(self, name, contents):
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)

    def keys(self, tools=None):
        paths = [path for path in Path('.').rglob('*') if path.is_file()]
        with patch.object(cache, 'command', return_value='1.16.2'):
            return cache.cache_keys('ios', 'arm64', paths, tools or self.tools)

    def test_dart_and_go_tests_do_not_invalidate_framework(self):
        original = self.keys()['framework_key']
        self.write('lib/main.dart', 'void main() { print("UI edit"); }')
        self.write('lantern-core/mobile/mobile_test.go', 'package mobile // new test')
        self.assertEqual(original, self.keys()['framework_key'])

    def test_production_sources_headers_and_embedded_data_invalidate(self):
        original = self.keys()['framework_key']
        for name in ('lantern-core/mobile/mobile.go',
                     'lantern-core/mobile/include/native.inc',
                     'lantern-core/mobile/data/identity.pem'):
            with self.subTest(name=name):
                self.write(name, 'changed input')
                self.assertNotEqual(original, self.keys()['framework_key'])
                original = self.keys()['framework_key']

    def test_go_embed_can_consume_test_named_files(self):
        for indent in ('', '    ', '\t'):
            with self.subTest(indent=indent):
                self.write('lantern-core/mobile/mobile.go',
                           f'package mobile\n{indent}//go:embed *.go\nvar sources embed.FS')
                self.write('lantern-core/mobile/mobile_test.go', 'original embedded data')
                original = self.keys()['framework_key']
                self.write('lantern-core/mobile/mobile_test.go', 'changed embedded data')
                self.assertNotEqual(original, self.keys()['framework_key'])

    def test_toolchain_or_target_change_invalidates_framework(self):
        original = self.keys()['framework_key']
        for key in ('target', 'host', 'macos', 'xcode', 'sdk', 'go', 'identity'):
            with self.subTest(key=key):
                tools = dict(self.tools, **{key: 'different'})
                self.assertNotEqual(original, self.keys(tools)['framework_key'])

    def test_deletion_and_executable_bit_invalidate(self):
        path = Path('lantern-core/mobile/mobile.go')
        original = self.keys()['framework_key']
        path.chmod(0o755)
        executable = self.keys()['framework_key']
        self.assertNotEqual(original, executable)
        path.unlink()
        self.assertNotEqual(executable, self.keys()['framework_key'])

    def test_pod_plugin_inputs_change_key_but_retain_compatible_prefix(self):
        original = self.keys()
        self.write('pubspec.lock', 'updated plugin')
        updated = self.keys()
        self.assertNotEqual(original['pods_key'], updated['pods_key'])
        self.assertEqual(original['pods_prefix'], updated['pods_prefix'])
        self.assertEqual(original['framework_key'], updated['framework_key'])
        self.assertNotEqual(updated['pods_prefix'],
                            self.keys(dict(self.tools, sdk='new SDK'))['pods_prefix'])

    def test_custom_compiler_flags_and_local_replacements_are_rejected(self):
        with patch.dict(os.environ, {'GOFLAGS': '-race'}):
            with self.assertRaisesRegex(ValueError, 'GOFLAGS'):
                cache.validate_environment()
        with patch.dict(os.environ, {}, clear=True), patch.object(
                cache, 'command', side_effect=['', '{"Replace":[{"New":{"Path":"../local"}}]}']):
            with self.assertRaisesRegex(ValueError, 'Local module'):
                cache.validate_environment()


if __name__ == '__main__':
    unittest.main()
