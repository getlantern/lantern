import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/features/report_issue/provider/attachment_picker.dart';

void main() {
  group('ReportIssueAttachmentRulesUtils', () {
    test('canonicalMimeType accepts common image aliases and parameters', () {
      expect(
        ReportIssueAttachmentRulesUtils.canonicalMimeType(
          name: 'screenshot.jpg',
          path: '',
          mimeType: 'image/jpg',
        ),
        'image/jpeg',
      );

      expect(
        ReportIssueAttachmentRulesUtils.canonicalMimeType(
          name: 'screenshot.png',
          path: '',
          mimeType: 'image/png; charset=binary',
        ),
        'image/png',
      );
    });

    test('picker image type group includes iOS uniform type identifiers', () {
      final typeGroup =
          PlatformReportIssueAttachmentPicker.acceptedTypeGroups.single;

      expect(
        typeGroup.extensions,
        ReportIssueAttachmentRulesUtils.allowedExtensions,
      );
      expect(
        typeGroup.uniformTypeIdentifiers,
        ReportIssueAttachmentRulesUtils.allowedAppleUniformTypeIdentifiers,
      );
    });
  });
}
