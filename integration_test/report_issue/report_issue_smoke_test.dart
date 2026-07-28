import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart' show AppTextField;
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';

/// Marks real submissions as automated so they're easy to ignore backend-side.
const _testDescription =
    'Automated integration test report — please ignore (report_issue smoke)';

/// Backend test account — bypasses the server-side report filters.
const _testEmail = 'radiancetest@getlantern.org';

final _descriptionField = find.byKey(const Key('report_issue.description'));
final _submitButton = find.byKey(const Key('report_issue.submit_button'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerReportIssueSmokeTests();
}

/// Exposed so an aggregator entrypoint (android_all_e2e_test.dart) can
/// register this suite alongside others.
void registerReportIssueSmokeTests() {
  group('Report issue smoke test', () {
    testWidgets('missing issue type blocks submit', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      await appRobot.openReportIssue();
      try {
        await _enterIssueDescription(tester, _testDescription);
        await appRobot.hideKeyboard();
        await _submitIssueReport(tester);

        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('please_select_an_issue'.i18n),
          timeout: const Duration(seconds: 10),
          reason: 'Missing issue-type validation error did not appear',
        );
      } finally {
        await _resetScreen(appRobot);
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
        await appRobot.hideKeyboard();
        await _submitIssueReport(tester);

        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('please_enter_valid_email'.i18n),
          timeout: const Duration(seconds: 10),
          reason: 'Invalid-email validation error did not appear',
        );
      } finally {
        await _resetScreen(appRobot);
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

        // Back to home: ReportIssue -> Support -> Settings -> Home.
        await appRobot.hideKeyboard();
        await appRobot.goBack();
        await appRobot.goBack();
        await appRobot.goBack();

        await appRobot.openReportIssue();

        expect(_descriptionText(tester), _testDescription);
        expect(
          find.descendant(
            of: find.byType(DropdownMenu<String>),
            matching: find.text('other'.i18n),
          ),
          findsOneWidget,
        );
      } finally {
        await _resetScreen(appRobot);
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
        await appRobot.hideKeyboard();
        await _submitIssueReport(tester);

        // Real network submission; give it time.
        e2eLog('Report submitted — waiting for server response');
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('thanks_for_feedback'.i18n),
          timeout: const Duration(seconds: 60),
          reason: 'Success snackbar did not appear after submit',
        );

        expect(_descriptionText(tester), isEmpty);
      } finally {
        await _resetScreen(appRobot);
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

  // .last: the overlay repeats the label. The overlay is height-capped
  // (CardDropdown menuHeight), so scroll it until the option is visible.
  final item = find.text(option).last;
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

/// Current text in the description field.
String _descriptionText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: _descriptionField,
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;


/// Clears the shared draft and returns to the root route.
Future<void> _resetScreen(AppRobot appRobot) async {
  final tester = appRobot.tester;
  if (_descriptionField.evaluate().isNotEmpty) {
    await tester.enterText(_descriptionField, '');
    await tester.pump();
  }
  if (_emailField().evaluate().isNotEmpty) {
    await tester.enterText(_emailField(), '');
    await tester.pump();
  }
  await appRobot.resetToRoot();
}
