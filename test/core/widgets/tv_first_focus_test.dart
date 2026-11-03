import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('a rebuild leaves focus where the user moved it', (tester) async {
    PlatformUtils.isTv = true;
    final theme = ValueNotifier(AppTheme.appTheme());
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: mobileSize,
        child: ValueListenableBuilder(
          valueListenable: theme,
          builder: (_, value, _) => MaterialApp(
            theme: value,
            home: const Scaffold(body: Text('host')),
          ),
        ),
      ),
    );
    showAppBottomSheet(
      context: tester.element(find.text('host')),
      title: 'sheet',
      builder: (_, _) => Column(
        children: [
          TextButton(onPressed: () {}, child: const Text('first')),
          TextButton(onPressed: () {}, child: const Text('second')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(buttonFocused(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    bool secondFocused() =>
        Focus.of(tester.element(find.text('second'))).hasPrimaryFocus;
    expect(secondFocused(), isTrue);

    // A theme change reruns the sheet builder.
    theme.value = AppTheme.appTheme().copyWith(primaryColor: Colors.red);
    await tester.pumpAndSettle();
    expect(secondFocused(), isTrue, reason: 'focus was not moved on');
  });

  testWidgets('dialog primary button takes focus on TV', (tester) async {
    PlatformUtils.isTv = true;
    final context = await pumpHost(tester);
    AppDialog.show(context: context, title: 'hi', primaryLabel: 'first');
    await tester.pumpAndSettle();
    expect(buttonFocused(tester), isTrue);
  });
}
