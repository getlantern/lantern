import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
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

    test(
      'addAttachments stores attachments and removeAttachment clears them',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const attachment = ReportIssueAttachment(
          name: 'vpn_error.png',
          path: '/tmp/vpn_error.png',
          mimeType: 'image/png',
          sizeBytes: 2048,
        );

        final notifier = container.read(reportIssueDraftProvider.notifier);
        notifier.addAttachments(const <ReportIssueAttachment>[attachment]);

        expect(
          container.read(reportIssueDraftProvider),
          const ReportIssueDraftState(
            attachments: <ReportIssueAttachment>[attachment],
          ),
        );

        notifier.removeAttachment(attachment);

        expect(
          container.read(reportIssueDraftProvider),
          const ReportIssueDraftState(),
        );
      },
    );

    test('addAttachments rejects invalid totals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const oversizedAttachment = ReportIssueAttachment(
        name: 'large.gif',
        path: '/tmp/large.gif',
        mimeType: 'image/gif',
        sizeBytes: ReportIssueAttachmentRulesUtils.maxTotalBytes + 1,
      );

      final notifier = container.read(reportIssueDraftProvider.notifier);
      notifier.addAttachments(const <ReportIssueAttachment>[
        oversizedAttachment,
      ]);

      expect(
        container.read(reportIssueDraftProvider),
        ReportIssueDraftState(
          attachmentError:
              ReportIssueAttachmentRulesUtils.totalSizeExceededMessage,
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
        ..setDescription('Steps to reproduce')
        ..addAttachments(const <ReportIssueAttachment>[
          ReportIssueAttachment(
            name: 'vpn_error.png',
            path: '/tmp/vpn_error.png',
            mimeType: 'image/png',
            sizeBytes: 2048,
          ),
        ]);

      notifier.clear();

      expect(
        container.read(reportIssueDraftProvider),
        const ReportIssueDraftState(),
      );
    });
  });
}
