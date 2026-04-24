import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';

void main() {
  group('ReportIssueAttachmentRules', () {
    test('canonicalMimeType accepts common image aliases and parameters', () {
      expect(
        ReportIssueAttachmentRules.canonicalMimeType(
          name: 'screenshot.jpg',
          path: '',
          mimeType: 'image/jpg',
        ),
        'image/jpeg',
      );

      expect(
        ReportIssueAttachmentRules.canonicalMimeType(
          name: 'screenshot.png',
          path: '',
          mimeType: 'image/png; charset=binary',
        ),
        'image/png',
      );
    });
  });
}
