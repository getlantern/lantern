import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import swift_ci


class InputTests(unittest.TestCase):
    def test_platform_isolation(self):
        for path in ['ios/Shared/Logger.swift', 'ios/Shared/bridge.h',
                     'ios/Podfile', 'ios/Podfile.lock',
                     'ios/Runner.xcodeproj/project.pbxproj']:
            with self.subTest(path=path):
                self.assertTrue(swift_ci.relevant(path, 'ios'))
                self.assertFalse(swift_ci.relevant(path, 'macos'))
        for path in ['macos/RunnerTests/RunnerTests.swift', 'macos/Shared/bridge.h',
                     'macos/Podfile', 'macos/Podfile.lock',
                     'macos/Runner.xcodeproj/project.pbxproj']:
            with self.subTest(path=path):
                self.assertTrue(swift_ci.relevant(path, 'macos'))
                self.assertFalse(swift_ci.relevant(path, 'ios'))

    def test_shared_inputs_invalidate_both(self):
        for path in ['go.mod', 'go.sum',
                     'lantern-core/mobile/mobile.go', 'scripts/ci/version.sh',
                     'ios/native_test.go',
                     'hook/build.dart',
                     '.github/actions/setup-go/action.yml',
                     '.github/actions/setup-flutter/action.yml',
                     '.github/actions/setup-flutter/read-version.sh',
                     'Makefile', 'pubspec.yaml', 'pubspec.lock', '.metadata',
                     '.github/flutter-version.yaml',
                     '.github/scripts/swift_framework_cache.py',
                     '.github/scripts/test_swift_framework_cache.py',
                     swift_ci.WORKFLOW, swift_ci.SCRIPT]:
            for platform in swift_ci.PLATFORMS:
                with self.subTest(path=path, platform=platform):
                    self.assertTrue(swift_ci.relevant(path, platform))

    def test_unrelated_edits_do_not_invalidate_native_builds(self):
        for path in ['lib/main.dart', 'lib/core/widgets/app_webview.dart',
                     'assets/locales/en.po', 'assets/images/logo.png',
                     'test/core/services/logger_service_test.dart', 'README.md',
                     'android/app/build.gradle', 'windows/runner/main.cpp',
                     '.github/actions/setup-android/action.yml']:
            for platform in swift_ci.PLATFORMS:
                with self.subTest(path=path, platform=platform):
                    self.assertFalse(swift_ci.relevant(path, platform))

    def test_macos_only_assets_keep_platform_packaging_validation(self):
        path = 'assets/images/flags/us.png'
        self.assertTrue(swift_ci.relevant(path, 'macos'))
        self.assertFalse(swift_ci.relevant(path, 'ios'))

    def test_native_sources_outside_platform_directories_invalidate_both(self):
        for path in ['bridge/native.c', 'bridge/native.h', 'bridge/native.cpp',
                     'bridge/native.mm', 'bridge/native.swift', 'bridge/native.S',
                     'bridge/native.rs', 'bridge/native_test.go',
                     'bridge/native.f', 'bridge/native.F', 'bridge/native.for',
                     'bridge/native.f90', 'bridge/native.syso', 'bridge/native.a',
                     'bridge/native.def', 'bridge/native.pc']:
            for platform in swift_ci.PLATFORMS:
                with self.subTest(path=path, platform=platform):
                    self.assertTrue(swift_ci.relevant(path, platform))

    def test_hash_detects_content_deletions_and_file_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            old = os.getcwd()
            os.chdir(directory)
            try:
                subprocess.run(['git', 'init', '-q'], check=True)
                subprocess.run(['git', 'config', 'user.email', 'ci@example.test'], check=True)
                subprocess.run(['git', 'config', 'user.name', 'CI Test'], check=True)
                Path('ios').mkdir()
                Path('test').mkdir()
                source = Path('ios/source.swift')
                source.write_text('first')

                def commit():
                    subprocess.run(['git', 'add', '-A'], check=True)
                    subprocess.run(['git', 'commit', '-qm', 'fixture'], check=True)

                commit()
                original = swift_ci.fingerprint('HEAD', 'ios')
                Path('test/unit.dart').write_text('test-only')
                commit()
                self.assertEqual(original, swift_ci.fingerprint('HEAD', 'ios'),
                                 'unrelated file must not move the digest')
                source.write_text('changed')
                commit()
                changed = swift_ci.fingerprint('HEAD', 'ios')
                self.assertNotEqual(original, changed, 'content change must move the digest')
                source.chmod(0o755)
                commit()
                self.assertNotEqual(changed, swift_ci.fingerprint('HEAD', 'ios'),
                                    'file mode change must move the digest')
                before_addition = swift_ci.fingerprint('HEAD', 'ios')
                Path('ios/new.swift').write_text('new native input')
                commit()
                self.assertNotEqual(before_addition, swift_ci.fingerprint('HEAD', 'ios'),
                                    'new native input must move the digest')
                before_deletion = swift_ci.fingerprint('HEAD', 'ios')
                source.unlink()
                commit()
                self.assertNotEqual(before_deletion, swift_ci.fingerprint('HEAD', 'ios'),
                                    'deletion must move the digest')
            finally:
                os.chdir(old)

    def test_dart_changes_skip_native_checks_until_dependencies_change(self):
        with tempfile.TemporaryDirectory() as directory:
            old = os.getcwd()
            os.chdir(directory)
            try:
                subprocess.run(['git', 'init', '-q'], check=True)
                subprocess.run(['git', 'config', 'user.email', 'ci@example.test'], check=True)
                subprocess.run(['git', 'config', 'user.name', 'CI Test'], check=True)
                paths = ['lib/main.dart',
                         'test/app_test.dart',
                         'pubspec.lock']
                for name in paths:
                    path = Path(name)
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('base')
                subprocess.run(['git', 'add', '-A'], check=True)
                subprocess.run(['git', 'commit', '-qm', 'base'], check=True)
                before = {platform: swift_ci.fingerprint('HEAD', platform)
                          for platform in swift_ci.PLATFORMS}
                for name in paths[:2]:
                    Path(name).write_text('updated Dart code')
                subprocess.run(['git', 'add', '-A'], check=True)
                subprocess.run(['git', 'commit', '-qm', 'Dart changes'], check=True)
                for platform in swift_ci.PLATFORMS:
                    self.assertEqual(before[platform], swift_ci.fingerprint('HEAD', platform))
                Path('pubspec.lock').write_text('native plugin version changed')
                subprocess.run(['git', 'add', '-A'], check=True)
                subprocess.run(['git', 'commit', '-qm', 'plugin update'], check=True)
                for platform in swift_ci.PLATFORMS:
                    self.assertNotEqual(before[platform], swift_ci.fingerprint('HEAD', platform))
            finally:
                os.chdir(old)


class PlanTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.outputs = Path(directory.name) / 'out'
        self.summary = Path(directory.name) / 'summary'
        self.env = {'GITHUB_OUTPUT': str(self.outputs), 'GITHUB_STEP_SUMMARY': str(self.summary)}

    def run_plan(self, event, event_name='pull_request'):
        with patch.dict(os.environ, dict(self.env, GITHUB_EVENT_NAME=event_name)):
            swift_ci.plan(event)
        return self.outputs.read_text()

    def test_unchanged_platform_is_skipped(self):
        event = {'pull_request': {'base': {'sha': 'base'}}}
        with patch.object(swift_ci, 'fingerprint', return_value='same'):
            written = self.run_plan(event)
        self.assertIn('ios_needed=false', written)
        self.assertIn('macos_needed=false', written)

    def test_changed_platform_is_built(self):
        event = {'pull_request': {'base': {'sha': 'base'}}}
        with patch.object(swift_ci, 'fingerprint', side_effect=lambda ref, _p: ref):
            written = self.run_plan(event)
        self.assertIn('ios_needed=true', written)
        self.assertIn('macos_needed=true', written)

    def test_syso_only_change_builds_both_platforms(self):
        with tempfile.TemporaryDirectory() as directory:
            old = os.getcwd()
            os.chdir(directory)
            try:
                subprocess.run(['git', 'init', '-q'], check=True)
                subprocess.run(['git', 'config', 'user.email', 'ci@example.test'], check=True)
                subprocess.run(['git', 'config', 'user.name', 'CI Test'], check=True)
                Path('bridge').mkdir()
                Path('bridge/native.go').write_text('package bridge')
                source = Path('bridge/native.syso')
                source.write_bytes(b'original object')
                subprocess.run(['git', 'add', '-A'], check=True)
                subprocess.run(['git', 'commit', '-qm', 'base'], check=True)
                base = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
                source.write_bytes(b'updated object')
                subprocess.run(['git', 'add', '-A'], check=True)
                subprocess.run(['git', 'commit', '-qm', 'native object update'], check=True)
                written = self.run_plan({'pull_request': {'base': {'sha': base}}})
                self.assertIn('ios_needed=true', written)
                self.assertIn('macos_needed=true', written)
            finally:
                os.chdir(old)

    def test_only_changed_platform_is_built(self):
        event = {'pull_request': {'base': {'sha': 'base'}}}
        with patch.object(swift_ci, 'fingerprint',
                          side_effect=lambda ref, platform: ref if platform == 'ios' else 'same'):
            written = self.run_plan(event)
        self.assertIn('ios_needed=true', written)
        self.assertIn('macos_needed=false', written)

    def test_missing_base_fails_instead_of_emitting_skip(self):
        event = {'pull_request': {'base': {'sha': 'missing'}}}
        with patch.object(swift_ci, 'fingerprint',
                          side_effect=subprocess.CalledProcessError(128, ['git', 'ls-tree'])):
            with self.assertRaises(subprocess.CalledProcessError):
                self.run_plan(event)
        self.assertFalse(self.outputs.exists())

    def test_manual_dispatch_always_builds(self):
        # The escape hatch must not consult fingerprints at all.
        with patch.object(swift_ci, 'fingerprint', side_effect=AssertionError('must not be called')):
            written = self.run_plan({}, event_name='workflow_dispatch')
        self.assertIn('ios_needed=true', written)
        self.assertIn('macos_needed=true', written)

    def test_main_push_compares_previous_tree_per_platform(self):
        with patch.object(swift_ci, 'fingerprint',
                          side_effect=lambda ref, platform: ref if platform == 'macos' else 'same') as fingerprint:
            written = self.run_plan({'before': 'previous'}, event_name='push')
        self.assertIn('ios_needed=false', written)
        self.assertIn('macos_needed=true', written)
        fingerprint.assert_any_call('previous', 'ios')
        fingerprint.assert_any_call('previous', 'macos')

    def test_main_push_with_unchanged_native_inputs_skips_both(self):
        with patch.object(swift_ci, 'fingerprint', return_value='same'):
            written = self.run_plan({'before': 'previous'}, event_name='push')
        self.assertIn('ios_needed=false', written)
        self.assertIn('macos_needed=false', written)

    def test_push_missing_or_zero_before_builds_both(self):
        for event in ({}, {'before': ''}, {'before': '0' * 40}):
            with self.subTest(event=event), patch.object(
                    swift_ci, 'fingerprint', side_effect=AssertionError('must not be called')):
                self.outputs.unlink(missing_ok=True)
                written = self.run_plan(event, event_name='push')
            self.assertIn('ios_needed=true', written)
            self.assertIn('macos_needed=true', written)

    def test_push_unavailable_previous_tree_fails_closed(self):
        with patch.object(swift_ci, 'fingerprint',
                          side_effect=subprocess.CalledProcessError(128, ['git', 'ls-tree'])):
            with self.assertRaises(subprocess.CalledProcessError):
                self.run_plan({'before': 'missing'}, event_name='push')
        self.assertFalse(self.outputs.exists())


if __name__ == '__main__':
    unittest.main()
