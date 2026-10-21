import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_dialog.dart';
import 'package:lantern/core/common/app_theme.dart';

void main() {
  testWidgets('dialog callback does not pop the route beneath the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        child: MaterialApp(theme: AppTheme.appTheme(), home: const _HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.open_page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog_page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dialog_page.open_dialog')));
    await tester.pumpAndSettle();
    expect(find.text('Dialog title'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Dialog title'), findsNothing);
    expect(find.byKey(const Key('dialog_page')), findsOneWidget);
    expect(find.byKey(const Key('home')), findsNothing);
  });

  testWidgets('secondary action can leave the dialog open until dismissed', (
    tester,
  ) async {
    var secondaryCalls = 0;
    var completed = false;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => AppDialog.show(
                  context: context,
                  title: 'Welcome',
                  primaryLabel: 'Got it',
                  secondaryLabel: 'Learn more',
                  dismissOnSecondary: false,
                  onSecondaryPressed: () => secondaryCalls++,
                ).whenComplete(() => completed = true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn more'));
    await tester.pumpAndSettle();
    expect(secondaryCalls, 1);
    expect(completed, isFalse);
    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Welcome'), findsNothing);
  });

  group('shareLogsWarningDialog', () {
    Future<void> pumpOpener(WidgetTester tester, void Function(bool) onResult) {
      return tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => onResult(
                    await AppDialog.shareLogsWarningDialog(context: context),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('cancel resolves false and closes the dialog', (tester) async {
      bool? result;
      await pumpOpener(tester, (v) => result = v);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('share_logs_warning_title'), findsOneWidget);

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('share_logs_warning_title'), findsNothing);
    });

    testWidgets('share resolves true and closes the dialog', (tester) async {
      bool? result;
      await pumpOpener(tester, (v) => result = v);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('share_logs_anyway'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('share_logs_warning_title'), findsNothing);
    });
  });
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home'),
      body: Center(
        child: ElevatedButton(
          key: const Key('home.open_page'),
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const _DialogPage()),
            );
          },
          child: const Text('Open page'),
        ),
      ),
    );
  }
}

class _DialogPage extends StatelessWidget {
  const _DialogPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('dialog_page'),
      body: Center(
        child: ElevatedButton(
          key: const Key('dialog_page.open_dialog'),
          onPressed: () {
            AppDialog.dialog(
              context: context,
              title: 'Dialog title',
              content: 'Dialog body',
              action: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            );
          },
          child: const Text('Open dialog'),
        ),
      ),
    );
  }
}
