import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/features/report_issue/provider/attachment_access.dart';
import 'package:lantern/features/report_issue/provider/attachment_budget.dart';
import 'package:lantern/features/report_issue/provider/submitter.dart';
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

class _FakeAttachmentBudget implements ReportIssueAttachmentBudget {
  int value;

  _FakeAttachmentBudget({this.value = 0});

  @override
  Future<int> reservedBytes() async => value;
}

class _FakeAttachmentAccess implements ReportIssueAttachmentAccess {
  bool wasUsed = false;
  Object? error;

  @override
  Future<T> withAccess<T>(
    List<ReportIssueAttachment> attachments,
    Future<T> Function() action,
  ) async {
    wasUsed = true;
    if (error != null) {
      throw error!;
    }
    return action();
  }
}

void main() {
  group('ReportIssueSubmitter', () {
    test('forwards attachments through to LanternService', () async {
      final fakeService = _FakeLanternService();
      final attachmentBudget = _FakeAttachmentBudget();
      final attachmentAccess = _FakeAttachmentAccess();
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
        attachmentAccess: attachmentAccess,
        attachmentBudget: attachmentBudget,
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
      expect(attachmentAccess.wasUsed, isTrue);
    });

    test('rejects oversize totals before calling LanternService', () async {
      final fakeService = _FakeLanternService();
      final attachmentBudget = _FakeAttachmentBudget(value: 1024);

      final submitter = ReportIssueSubmitter(
        fakeService,
        attachmentBudget: attachmentBudget,
        deviceInfoLoader: () async => ('iOS', 'iPhone'),
        logFileResolver: () async => null,
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
            sizeBytes: ReportIssueAttachmentRulesUtils.maxTotalBytes,
          ),
        ],
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(
          failure.localizedErrorMessage,
          ReportIssueAttachmentRulesUtils.totalSizeExceededMessage,
        ),
        (_) => fail('Expected submitter to reject the oversized payload'),
      );
      expect(fakeService.attachments, isNull);
    });

    test(
      'returns a readable failure when scoped access cannot be restored',
      () async {
        final fakeService = _FakeLanternService();
        final attachmentAccess = _FakeAttachmentAccess()
          ..error = ReportIssueAttachmentAccessException(
            ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
          );

        final submitter = ReportIssueSubmitter(
          fakeService,
          attachmentAccess: attachmentAccess,
          attachmentBudget: _FakeAttachmentBudget(),
          deviceInfoLoader: () async => ('macOS', 'MacBook Pro'),
          logFileResolver: () async => null,
        );

        final result = await submitter.submit(
          email: '',
          issueType: 'other',
          description: 'Need help',
          attachments: const <ReportIssueAttachment>[
            ReportIssueAttachment(
              name: 'vpn_error.png',
              path: '/tmp/vpn_error.png',
              mimeType: 'image/png',
              sizeBytes: 4096,
              securityScopedBookmark: 'bookmark',
            ),
          ],
        );

        expect(result.isLeft(), isTrue);
        result.match(
          (failure) => expect(
            failure.localizedErrorMessage,
            ReportIssueAttachmentRulesUtils.unreadableAttachmentMessage,
          ),
          (_) => fail('Expected scoped access restoration to fail'),
        );
        expect(fakeService.attachments, isNull);
        expect(attachmentAccess.wasUsed, isTrue);
      },
    );

    test('submit without screenshots keeps the legacy path working', () async {
      final fakeService = _FakeLanternService();
      final submitter = ReportIssueSubmitter(
        fakeService,
        attachmentBudget: _FakeAttachmentBudget(),
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
