import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/features/report_issue/report_issue.dart';

void main() {
  testWidgets('description draft survives leaving and reopening the screen', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget buildScreen() {
      return UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const ReportIssue(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final descriptionField = find.byKey(const Key('report_issue.description'));

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
}
