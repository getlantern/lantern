import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import swift_ci


class InputTests(unittest.TestCase):
    def test_platform_isolation(self):
        self.assertTrue(swift_ci.relevant('ios/Shared/Logger.swift', 'ios'))
        self.assertFalse(swift_ci.relevant('ios/Shared/Logger.swift', 'macos'))
        self.assertTrue(swift_ci.relevant('macos/RunnerTests/RunnerTests.swift', 'macos'))
        self.assertFalse(swift_ci.relevant('macos/RunnerTests/RunnerTests.swift', 'ios'))

    def test_shared_inputs_invalidate_both(self):
        for path in ['lib/main.dart', 'assets/locales/en.po', 'go.mod', 'go.sum',
                     'lantern-core/mobile/mobile.go', 'scripts/ci/version.sh',
                     '.github/actions/setup-go/action.yml',
                     '.github/actions/setup-flutter/action.yml',
                     '.github/actions/setup-flutter/read-version.sh',
                     'Makefile', 'pubspec.lock', swift_ci.WORKFLOW, swift_ci.SCRIPT]:
            for platform in swift_ci.PLATFORMS:
                with self.subTest(path=path, platform=platform):
                    self.assertTrue(swift_ci.relevant(path, platform))

    def test_unrelated_edits_do_not_invalidate_native_builds(self):
        for path in ['test/core/services/logger_service_test.dart', 'README.md',
                     'android/app/build.gradle', 'windows/runner/main.cpp',
                     '.github/actions/setup-android/action.yml']:
            for platform in swift_ci.PLATFORMS:
                with self.subTest(path=path, platform=platform):
                    self.assertFalse(swift_ci.relevant(path, platform))

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
                source.unlink()
                commit()
                self.assertNotEqual(original, swift_ci.fingerprint('HEAD', 'ios'),
                                    'deletion must move the digest')
            finally:
                os.chdir(old)


class PlanTests(unittest.TestCase):
    def setUp(self):
        self.outputs = Path(tempfile.mkdtemp()) / 'out'
        self.summary = Path(tempfile.mkdtemp()) / 'summary'
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

    def test_manual_dispatch_always_builds(self):
        # The escape hatch must not consult fingerprints at all.
        with patch.object(swift_ci, 'fingerprint', side_effect=AssertionError('must not be called')):
            written = self.run_plan({}, event_name='workflow_dispatch')
        self.assertIn('ios_needed=true', written)
        self.assertIn('macos_needed=true', written)

    def test_push_without_pull_request_builds(self):
        # No base to compare against, so there is no evidence to skip on.
        with patch.object(swift_ci, 'fingerprint', return_value='same'):
            written = self.run_plan({}, event_name='push')
        self.assertIn('ios_needed=true', written)
        self.assertIn('macos_needed=true', written)


if __name__ == '__main__':
    unittest.main()
