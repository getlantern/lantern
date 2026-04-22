import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/features/report_issue/services/report_issue_submitter.dart';
import 'package:lantern/lantern/lantern_service.dart';

class _FakeLanternService implements LanternService {
  String? email;
  String? issueType;
  String? description;
  String? device;
  String? model;
  String? logFilePath;
  List<ReportIssueAttachment>? attachments;
  Either<Failure, Unit> reportIssueResult = right(unit);

  @override
  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
    List<ReportIssueAttachment> attachments,
  ) async {
    this.email = email;
    this.issueType = issueType;
    this.description = description;
    this.device = device;
    this.model = model;
    this.logFilePath = logFilePath;
    this.attachments = List<ReportIssueAttachment>.unmodifiable(attachments);
    return reportIssueResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReportIssueSubmitter', () {
    test('forwards attachments through to LanternService', () async {
      final fakeService = _FakeLanternService();
      const attachment = ReportIssueAttachment(
        name: 'vpn_error.png',
        path: '/tmp/vpn_error.png',
        mimeType: 'image/png',
        sizeBytes: 4096,
      );

      final tempDir = await Directory.systemTemp.createTemp('report-issue');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final logFile = File('${tempDir.path}/flutter.log')
        ..writeAsStringSync('flutter log');

      final submitter = ReportIssueSubmitter(
        fakeService,
        deviceInfoLoader: () async => ('macOS', 'MacBook Pro'),
        logFileResolver: () async => logFile,
      );

      final result = await submitter.submit(
        email: 'person@example.com',
        issueType: 'other',
        description: 'VPN drops while connecting',
        attachments: const <ReportIssueAttachment>[attachment],
      );

      expect(result.isRight(), isTrue);
      expect(fakeService.email, 'person@example.com');
      expect(fakeService.issueType, 'other');
      expect(fakeService.description, 'VPN drops while connecting');
      expect(fakeService.device, 'macOS');
      expect(fakeService.model, 'MacBook Pro');
      expect(fakeService.logFilePath, logFile.path);
      expect(fakeService.attachments, const <ReportIssueAttachment>[
        attachment,
      ]);
    });

    test('rejects oversize totals before calling LanternService', () async {
      final fakeService = _FakeLanternService();
      final tempDir = await Directory.systemTemp.createTemp('report-issue');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final logFile = File('${tempDir.path}/flutter.log')
        ..writeAsBytesSync(List<int>.filled(1024, 1));

      final submitter = ReportIssueSubmitter(
        fakeService,
        deviceInfoLoader: () async => ('iOS', 'iPhone'),
        logFileResolver: () async => logFile,
      );

      final result = await submitter.submit(
        email: '',
        issueType: 'slow',
        description: '',
        attachments: const <ReportIssueAttachment>[
          ReportIssueAttachment(
            name: 'huge.png',
            path: '/tmp/huge.png',
            mimeType: 'image/png',
            sizeBytes: ReportIssueAttachmentRules.maxTotalBytes,
          ),
        ],
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(
          failure.localizedErrorMessage,
          ReportIssueAttachmentRules.totalSizeExceededMessage,
        ),
        (_) => fail('Expected submitter to reject the oversized payload'),
      );
      expect(fakeService.attachments, isNull);
    });

    test('submit without screenshots keeps the legacy path working', () async {
      final fakeService = _FakeLanternService();
      final submitter = ReportIssueSubmitter(
        fakeService,
        deviceInfoLoader: () async => ('Windows', 'Surface'),
        logFileResolver: () async => null,
      );

      final result = await submitter.submit(
        email: '',
        issueType: 'slow',
        description: 'Still broken',
        attachments: const <ReportIssueAttachment>[],
      );

      expect(result.isRight(), isTrue);
      expect(fakeService.logFilePath, isEmpty);
      expect(fakeService.attachments, isEmpty);
    });
  });
}
