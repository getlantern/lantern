import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme, SecondaryButton;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/windows_executable_picker.dart';

class _Apps extends SplitTunnelingApps {
  final added = <String>[];
  Failure? failure;

  @override
  FutureOr<Set<AppData>> build() => {};

  @override
  Future<Failure?> addExecutable(String path) async {
    added.add(path);
    return failure;
  }
}

Future<void> _pumpPicker(
  WidgetTester tester,
  _Apps apps,
  Future<String?> Function() picker,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        splitTunnelingAppsProvider.overrideWith(() => apps),
        windowsExecutablePickerProvider.overrideWithValue(picker),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: WindowsExecutablePicker(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const button = ValueKey('add-windows-executable');

  testWidgets('cancellation changes nothing and re-enables the picker', (
    tester,
  ) async {
    final apps = _Apps();
    final selected = Completer<String?>();
    await _pumpPicker(tester, apps, () => selected.future);
    await tester.tap(find.byKey(button));
    await tester.pump();
    expect(tester.widget<SecondaryButton>(find.byKey(button)).enabled, isFalse);

    selected.complete(null);
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
    expect(tester.widget<SecondaryButton>(find.byKey(button)).enabled, isTrue);
  });

  testWidgets('adds the selected executable exactly once', (tester) async {
    final apps = _Apps();
    const path = r'C:\Games\Game.exe';
    final selected = Completer<String?>();
    var calls = 0;
    await _pumpPicker(tester, apps, () {
      calls++;
      return selected.future;
    });
    await tester.tap(find.byKey(button));
    await tester.pump();
    await tester.tap(find.byKey(button));
    selected.complete(path);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(apps.added, [path]);
  });

  testWidgets('shows core failure and allows retry', (tester) async {
    final apps = _Apps()
      ..failure = Failure(error: 'failed', localizedErrorMessage: 'Try again');
    await _pumpPicker(tester, apps, () async => r'C:\Games\Game.exe');
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.widget<SecondaryButton>(find.byKey(button)).enabled, isTrue);
  });

  testWidgets('picker exceptions are reported without adding a rule', (
    tester,
  ) async {
    final apps = _Apps();
    await _pumpPicker(
      tester,
      apps,
      () async => throw StateError('picker failed'),
    );
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(find.text('unable_to_add_executable'), findsOneWidget);
    expect(apps.added, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the screen while picking does not add a rule', (
    tester,
  ) async {
    final apps = _Apps();
    final selected = Completer<String?>();
    await _pumpPicker(tester, apps, () => selected.future);
    await tester.tap(find.byKey(button));
    await tester.pumpWidget(const SizedBox());
    selected.complete(r'C:\Games\Game.exe');
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
