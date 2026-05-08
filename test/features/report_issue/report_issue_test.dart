import 'dart:collection';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment_rules.dart';
import 'package:lantern/features/report_issue/report_issue.dart';
import 'package:lantern/features/report_issue/provider/attachment_picker.dart';
import 'package:lantern/features/report_issue/provider/attachment_budget.dart';
import 'package:lantern/features/report_issue/provider/submitter.dart';
import 'package:lantern/features/report_issue/widgets/report_issue_attachment_dropzone.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:loader_overlay/loader_overlay.dart';

class _FakeAttachmentPicker implements ReportIssueAttachmentPicker {
  final Queue<List<ReportIssueAttachment>> _pickResults =
      Queue<List<ReportIssueAttachment>>();

  @override
  bool supportsDesktopDropTarget = false;

  void enqueuePickResult(List<ReportIssueAttachment> attachments) {
    _pickResults.add(attachments);
  }

  @override
  Future<List<ReportIssueAttachment>> pickImages() async {
    return _pickResults.isEmpty
        ? const <ReportIssueAttachment>[]
        : _pickResults.removeFirst();
  }

  @override
  Future<List<ReportIssueAttachment>> loadDroppedFiles(
    Iterable<XFile> files,
  ) async {
    return const <ReportIssueAttachment>[];
  }
}

class _NoopLanternService implements LanternService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttachmentBudget implements ReportIssueAttachmentBudget {
  int value = 0;

  @override
  Future<int> reservedBytes() async => value;
}

class _SubmitCall {
  final String email;
  final String issueType;
  final String description;
  final List<ReportIssueAttachment> attachments;

  const _SubmitCall({
    required this.email,
    required this.issueType,
    required this.description,
    required this.attachments,
  });
}

class _FakeReportIssueSubmitter extends ReportIssueSubmitter {
  final List<_SubmitCall> calls = <_SubmitCall>[];
  Either<Failure, Unit> result = right(unit);

  _FakeReportIssueSubmitter() : super(_NoopLanternService());

  @override
  Future<Either<Failure, Unit>> submit({
    required String email,
    required String issueType,
    required String description,
    required List<ReportIssueAttachment> attachments,
  }) async {
    calls.add(
      _SubmitCall(
        email: email,
        issueType: issueType,
        description: description,
        attachments: List<ReportIssueAttachment>.unmodifiable(attachments),
      ),
    );
    return result;
  }
}

void main() {
  group('ReportIssue', () {
    late _FakeAttachmentPicker picker;
    late _FakeAttachmentBudget attachmentBudget;
    late _FakeReportIssueSubmitter submitter;
    late ProviderContainer container;

    setUp(() {
      picker = _FakeAttachmentPicker();
      attachmentBudget = _FakeAttachmentBudget();
      submitter = _FakeReportIssueSubmitter();
      container = ProviderContainer(
        overrides: [
          reportIssueAttachmentPickerProvider.overrideWithValue(picker),
          reportIssueAttachmentBudgetProvider.overrideWithValue(
            attachmentBudget,
          ),
          reportIssueSubmitterProvider.overrideWithValue(submitter),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget buildScreen({ReportIssue screen = const ReportIssue()}) {
      return UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: GlobalLoaderOverlay(
            child: MaterialApp(theme: AppTheme.appTheme(), home: screen),
          ),
        ),
      );
    }

    testWidgets('description draft survives leaving and reopening the screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final descriptionField = find.byKey(
        const Key('report_issue.description'),
      );

      expect(descriptionField, findsOneWidget);

      await tester.enterText(descriptionField, 'VPN drops while reproducing');
      await tester.pump();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('VPN drops while reproducing'), findsOneWidget);
    });

    testWidgets('adds and removes screenshot attachments', (tester) async {
      const attachment = ReportIssueAttachment(
        name: 'vpn_error.png',
        path: '/tmp/vpn_error.png',
        mimeType: 'image/png',
        sizeBytes: 2516582,
      );
      picker.enqueuePickResult(const <ReportIssueAttachment>[attachment]);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final addButton = find.byKey(
        const Key('report_issue.attachments.add_button'),
      );
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('vpn_error.png'), findsOneWidget);
      expect(find.text(attachment.formattedSize), findsOneWidget);
      expect(
        tester
            .widget<ReportIssueAttachmentDropzone>(
              find.byType(ReportIssueAttachmentDropzone),
            )
            .compact,
        isTrue,
      );

      await tester.tap(find.byTooltip('Remove vpn_error.png'));
      await tester.pumpAndSettle();

      expect(find.text('vpn_error.png'), findsNothing);
    });

    testWidgets('shows validation error for oversized selections', (
      tester,
    ) async {
      const almostFullAttachment = ReportIssueAttachment(
        name: 'huge.gif',
        path: '/tmp/huge.gif',
        mimeType: 'image/gif',
        sizeBytes: ReportIssueAttachmentRulesUtils.maxTotalBytes - 512,
      );
      attachmentBudget.value = 1024;
      picker.enqueuePickResult(const <ReportIssueAttachment>[
        almostFullAttachment,
      ]);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final addButton = find.byKey(
        const Key('report_issue.attachments.add_button'),
      );
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(
        find.text(ReportIssueAttachmentRulesUtils.totalSizeExceededMessage),
        findsOneWidget,
      );
      expect(find.text('huge.gif'), findsNothing);
    });

    testWidgets(
      'submits without screenshots and keeps the legacy path working',
      (tester) async {
        await tester.pumpWidget(
          buildScreen(screen: const ReportIssue(type: '0')),
        );
        await tester.pumpAndSettle();

        final submitButton = find.byKey(
          const Key('report_issue.submit_button'),
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(submitter.calls, hasLength(1));
        expect(submitter.calls.single.attachments, isEmpty);
        expect(submitter.calls.single.email, isEmpty);
        expect(submitter.calls.single.description, isEmpty);
      },
    );
  });
}
