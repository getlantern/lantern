import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart';

void main() {
  tearDown(() => PlatformUtils.isTv = false);

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: mobileSize,
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(body: Text('host')),
        ),
      ),
    );
    return tester.element(find.text('host'));
  }

  bool buttonFocused(WidgetTester tester) =>
      Focus.of(tester.element(find.text('first'))).hasPrimaryFocus;

  group('bottom sheet', () {
    for (final tv in [true, false]) {
      testWidgets('first control ${tv ? 'takes' : 'does not take'} focus'
          ' when isTv=$tv', (tester) async {
        PlatformUtils.isTv = tv;
        final context = await pumpHost(tester);
        showAppBottomSheet(
          context: context,
          title: 'sheet',
          builder: (_, _) =>
              TextButton(onPressed: () {}, child: const Text('first')),
        );
        await tester.pumpAndSettle();
        expect(buttonFocused(tester), tv);
      });
    }
  });

  testWidgets('dialog primary button takes focus on TV', (tester) async {
    PlatformUtils.isTv = true;
    final context = await pumpHost(tester);
    AppDialog.show(context: context, title: 'hi', primaryLabel: 'first');
    await tester.pumpAndSettle();
    expect(buttonFocused(tester), isTrue);
  });
}
