import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart' show AppTextField, appRouter;
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';

/// Description used for real submissions so the reports are easy to spot and
/// ignore on the backend.
const _testDescription =
    'Automated integration test report — please ignore (report_issue smoke)';

/// Test account recognized by the backend — reports from this address bypass
/// the server-side filters, so automated submissions don't pollute real data.
const _testEmail = 'radiancetest@getlantern.org';

final _descriptionField = find.byKey(const Key('report_issue.description'));
final _submitButton = find.byKey(const Key('report_issue.submit_button'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerReportIssueSmokeTests();
}

/// Registers the report-issue scenarios. Exposed separately so a
/// cross-feature aggregator entrypoint (e.g. android_all_e2e_test.dart) can
/// pull these in alongside other suites without duplicating the list.
void registerReportIssueSmokeTests() {
  group('Report issue smoke test', () {
    testWidgets('missing issue type blocks submit', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openReportIssue();
      try {
        await _enterIssueDescription(tester, _testDescription);
        await _submitIssueReport(tester);

        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('please_select_an_issue'.i18n),
          timeout: const Duration(seconds: 10),
          reason: 'Missing issue-type validation error did not appear',
        );
      } finally {
        await _resetScreen(tester);
      }
    });

    testWidgets('invalid email blocks submit', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openReportIssue();
      try {
        await tester.enterText(_emailField(), 'not-an-email');
        await tester.pumpAndSettle();
        await _selectIssueType(tester, 'other'.i18n);
        await _enterIssueDescription(tester, _testDescription);
        await _submitIssueReport(tester);

        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('please_enter_valid_email'.i18n),
          timeout: const Duration(seconds: 10),
          reason: 'Invalid-email validation error did not appear',
        );
      } finally {
        await _resetScreen(tester);
      }
    });

    testWidgets('saves draft when leaving and returning', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openReportIssue();
      try {
        await _selectIssueType(tester, 'other'.i18n);
        await _enterIssueDescription(tester, _testDescription);

        // Walk back to home one screen at a time:
        // ReportIssue -> Support -> Settings -> Home.
        await appRobot.goBack();
        await appRobot.goBack();
        await appRobot.goBack();

        // Then return to the report screen through the same UI flow.
        await appRobot.openReportIssue();

        // The draft restores both the description and the issue type.
        expect(_descriptionText(tester), _testDescription);
        expect(
          find.descendant(
            of: find.byType(DropdownMenu<String>),
            matching: find.text('other'.i18n),
          ),
          findsOneWidget,
        );
      } finally {
        await _resetScreen(tester);
      }
    });

    testWidgets('submit succeeds and clears draft', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openReportIssue();
      try {
        await tester.enterText(_emailField(), _testEmail);
        await tester.pumpAndSettle();
        await _selectIssueType(tester, 'other'.i18n);
        await _enterIssueDescription(tester, _testDescription);
        await _submitIssueReport(tester);

        // Real submission over the network; give it time.
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('thanks_for_feedback'.i18n),
          timeout: const Duration(seconds: 60),
          reason: 'Success snackbar did not appear after submit',
        );

        // Successful submit clears the draft.
        expect(_descriptionText(tester), isEmpty);
      } finally {
        await _resetScreen(tester);
      }
    });
  });
}

Finder _emailField() => find
    .descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'email'.i18n,
      ),
      matching: find.byType(TextField),
    )
    .first;

Future<void> _selectIssueType(WidgetTester tester, String option) async {
  await tester.tap(find.byType(DropdownMenu<String>));
  await tester.pumpAndSettle();

  // The menu renders the label a second time in the overlay; target that one.
  final item = find.text(option).last;
  // The menu overlay is height-capped (CardDropdown menuHeight), so late
  // options like "Other" sit below the fold — scroll the overlay's own
  // scrollable (the most recently opened one) until the option is visible.
  await tester.scrollUntilVisible(
    item,
    56,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();

  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _enterIssueDescription(WidgetTester tester, String text) async {
  await tester.enterText(_descriptionField, text);
  await tester.pumpAndSettle();
}

Future<void> _submitIssueReport(WidgetTester tester) async {
  await tester.ensureVisible(_submitButton);
  await tester.tap(_submitButton);

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Current content of the description field, for assertions.
String _descriptionText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: _descriptionField,
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

/// Clears anything this scenario left in the shared draft so the next one
/// starts clean, then returns to the root route.
Future<void> _resetScreen(WidgetTester tester) async {
  if (_descriptionField.evaluate().isNotEmpty) {
    await tester.enterText(_descriptionField, '');
    await tester.pump();
  }
  if (_emailField().evaluate().isNotEmpty) {
    await tester.enterText(_emailField(), '');
    await tester.pump();
  }
  appRouter.popUntilRoot();
  await tester.pumpAndSettle();
}
