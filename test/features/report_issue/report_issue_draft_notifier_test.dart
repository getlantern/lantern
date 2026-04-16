import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/report_issue/provider/report_issue_draft_notifier.dart';

void main() {
  group('ReportIssueDraft', () {
    test('seedFromRoute only fills empty values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reportIssueDraftProvider.notifier);

      notifier.seedFromRoute(description: '#3120', issueType: 'slow');

      expect(
        container.read(reportIssueDraftProvider),
        const ReportIssueDraftState(description: '#3120', issueType: 'slow'),
      );

      notifier
        ..setDescription('My own notes')
        ..setIssueType('cannot_sign_in');

      notifier.seedFromRoute(description: '#9999', issueType: 'other');

      expect(
        container.read(reportIssueDraftProvider),
        const ReportIssueDraftState(
          description: 'My own notes',
          issueType: 'cannot_sign_in',
        ),
      );
    });

    test('clear drops the draft', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reportIssueDraftProvider.notifier);

      notifier
        ..setEmail('me@example.com')
        ..setIssueType('slow')
        ..setDescription('Steps to reproduce');

      notifier.clear();

      expect(
        container.read(reportIssueDraftProvider),
        const ReportIssueDraftState(),
      );
    });
  });
}
