import json
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
                     'Makefile', 'pubspec.lock', swift_ci.WORKFLOW, swift_ci.SCRIPT]:
            for platform in swift_ci.JOB_NAMES:
                with self.subTest(path=path, platform=platform):
                    self.assertTrue(swift_ci.relevant(path, platform))

    def test_unrelated_edits_do_not_invalidate_native_builds(self):
        for path in ['test/core/services/logger_service_test.dart', 'README.md',
                     'android/app/build.gradle', 'windows/runner/main.cpp']:
            for platform in swift_ci.JOB_NAMES:
                self.assertFalse(swift_ci.relevant(path, platform))

    def test_swift_edits_reuse_go_framework_but_go_edits_do_not(self):
        self.assertFalse(swift_ci.relevant('ios/Shared/Logger.swift', 'ios', True))
        self.assertTrue(swift_ci.relevant('lantern-core/mobile/mobile.go', 'ios', True))

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
                self.assertEqual(original, swift_ci.fingerprint('HEAD', 'ios'))
                source.write_text('changed')
                commit()
                changed = swift_ci.fingerprint('HEAD', 'ios')
                self.assertNotEqual(original, changed)
                source.chmod(0o755)
                commit()
                self.assertNotEqual(changed, swift_ci.fingerprint('HEAD', 'ios'))
                source.unlink()
                commit()
                self.assertNotEqual(original, swift_ci.fingerprint('HEAD', 'ios'))
            finally:
                os.chdir(old)


class ArtifactTests(unittest.TestCase):
    event = {'repository': {'default_branch': 'main'}, 'pull_request': {'number': 9014}}

    def run_data(self, event='pull_request', number=9014):
        return {'path': swift_ci.WORKFLOW, 'head_repository': {'full_name': 'getlantern/lantern'},
                'event': event, 'head_branch': 'main' if event == 'push' else 'feature',
                'pull_requests': [{'number': number}]}

    def test_only_same_pr_or_main_can_supply_evidence(self):
        self.assertTrue(swift_ci.trusted_run(self.run_data(), self.event, 'getlantern/lantern'))
        self.assertTrue(swift_ci.trusted_run(self.run_data('push'), self.event, 'getlantern/lantern'))
        self.assertFalse(swift_ci.trusted_run(self.run_data(number=9999), self.event, 'getlantern/lantern'))
        run = self.run_data()
        run['path'] = '.github/workflows/other.yml'
        self.assertFalse(swift_ci.trusted_run(run, self.event, 'getlantern/lantern'))
        run = self.run_data()
        run['head_repository']['full_name'] = 'fork/lantern'
        self.assertFalse(swift_ci.trusted_run(run, self.event, 'getlantern/lantern'))

    @patch.dict(os.environ, {'GITHUB_REPOSITORY': 'getlantern/lantern', 'GITHUB_RUN_ID': '100'})
    def test_only_successful_platform_jobs_are_reused(self):
        artifact = {'id': 9, 'name': 'match', 'expired': False, 'workflow_run': {'id': 99}}
        for conclusion in ['failure', 'cancelled', None, 'success']:
            with patch.object(swift_ci, 'api', side_effect=[{'artifacts': [artifact]}, self.run_data(),
                    {'jobs': [{'name': swift_ci.JOB_NAMES['ios'], 'conclusion': conclusion}]}]):
                found = swift_ci.find_artifact('match', 'ios', self.event)
                self.assertEqual(found is not None, conclusion == 'success')

    @patch.dict(os.environ, {'GITHUB_REPOSITORY': 'getlantern/lantern', 'GITHUB_RUN_ID': '100'})
    def test_expired_wrong_name_and_current_run_are_ignored(self):
        for name, expired, run in [('match', True, 99), ('different', False, 99), ('match', False, 100)]:
            with patch.object(swift_ci, 'api', return_value={'artifacts': [
                    {'id': 9, 'name': name, 'expired': expired, 'workflow_run': {'id': run}}]}):
                self.assertIsNone(swift_ci.find_artifact('match', 'ios', self.event))

    @patch.dict(os.environ, {'GITHUB_REPOSITORY': 'getlantern/lantern'})
    def test_api_failure_builds_instead(self):
        with patch.object(swift_ci, 'api', side_effect=subprocess.CalledProcessError(1, 'gh')):
            self.assertIsNone(swift_ci.find_artifact('match', 'ios', self.event))

    def test_plan_reuses_success_and_manual_dispatch_forces_build(self):
        for event_name, expected in [('pull_request', 'false'), ('workflow_dispatch', 'true')]:
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / 'output'
                with patch.dict(os.environ, {'GITHUB_EVENT_NAME': event_name, 'GITHUB_OUTPUT': str(output),
                        'GITHUB_STEP_SUMMARY': str(Path(directory) / 'summary'),
                        'GITHUB_REPOSITORY': 'getlantern/lantern'}), \
                        patch.object(swift_ci, 'fingerprint', return_value='digest'), \
                        patch.object(swift_ci, 'find_artifact', return_value={'workflow_run': {'id': 99}}):
                    swift_ci.plan({'repository': {'default_branch': 'main'}})
                self.assertIn('ios_needed=' + expected, output.read_text())
                self.assertIn('macos_needed=' + expected, output.read_text())

    def test_platform_with_no_changes_skips_without_history(self):
        event = {**self.event, 'pull_request': {'number': 9014, 'base': {'sha': 'base'}}}
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            with patch.dict(os.environ, {'GITHUB_EVENT_NAME': 'pull_request', 'GITHUB_OUTPUT': str(output),
                    'GITHUB_STEP_SUMMARY': str(Path(directory) / 'summary')}), \
                    patch.object(swift_ci, 'fingerprint', return_value='same'), \
                    patch.object(swift_ci, 'find_artifact') as find:
                swift_ci.plan(event)
                find.assert_not_called()
            self.assertIn('ios_needed=false', output.read_text())
