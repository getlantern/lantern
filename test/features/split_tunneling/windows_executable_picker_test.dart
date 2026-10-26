import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme, SecondaryButton;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/windows_executable_picker.dart';

class _Apps extends SplitTunnelingApps {
  final added = <String>[];
  final toggled = <AppData>[];
  Failure? failure;

  @override
  FutureOr<Set<AppData>> build() => {};

  @override
  Future<Failure?> addExecutable(String path) async {
    added.add(path);
    return failure;
  }

  @override
  Future<void> toggleApp(AppData app) async => toggled.add(app);
}

class _Storage implements LocalStorageService {
  bool seen = true;
  int confirmations = 0;
  Completer<void>? pendingSave;

  @override
  bool get hasSeenBypassAppDialog => seen;

  @override
  Future<void> markBypassAppDialogSeen() async {
    confirmations++;
    await pendingSave?.future;
    seen = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpPicker(
  WidgetTester tester,
  _Apps apps,
  Future<String?> Function() picker, {
  List<AppData> installed = const [],
  Stream<List<AppData>>? catalog,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        splitTunnelingAppsProvider.overrideWith(() => apps),
        appsDataProvider.overrideWith(
          (ref) => catalog ?? Stream.value(installed),
        ),
        windowsExecutablePickerProvider.overrideWithValue(picker),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.appTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: WindowsExecutablePicker(
                confirmBypass: AppsSplitTunneling.confirmAppBypass,
              ),
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
  late _Storage storage;

  setUp(() async {
    await sl.reset();
    storage = _Storage();
    sl.registerSingleton<LocalStorageService>(storage);
  });

  tearDown(() => sl.reset());

  Finder dialogAction(String label) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

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

  for (final browser in [false, true]) {
    testWidgets(
      'installed ${browser ? 'browser' : 'app'} uses the same confirmation',
      (tester) async {
        storage.seen = false;
        final apps = _Apps();
        final app = AppData(
          name: 'Discovered app',
          bundleId: '',
          isBrowser: browser,
        );
        await _pumpPicker(tester, apps, () async => null);
        final context = tester.element(find.byType(WindowsExecutablePicker));
        for (final confirm in [false, true]) {
          final pending = const AppsSplitTunneling().onTapAddApp(
            context,
            apps,
            app,
          );
          await tester.pumpAndSettle();
          expect(apps.toggled, isEmpty);
          await tester.tap(
            dialogAction(confirm ? (browser ? 'add_anyway' : 'add') : 'cancel'),
          );
          await tester.pumpAndSettle();
          await pending;
          expect(apps.toggled, confirm ? [app] : isEmpty);
        }
        expect(apps.added, isEmpty);
      },
    );

    for (final confirm in [false, true]) {
      testWidgets(
        '${browser ? 'browser warning' : 'first-use explanation'} ${confirm ? 'adds only after confirmation' : 'can be cancelled'}',
        (tester) async {
          storage.seen = false;
          final apps = _Apps();
          const path = r'C:/GAMES/./Game.EXE';
          await _pumpPicker(
            tester,
            apps,
            () async => path,
            installed: [
              AppData(
                name: 'Discovered app',
                bundleId: '',
                appPath: r'C:\Games\Game.exe',
                isBrowser: browser,
              ),
            ],
          );
          await tester.tap(find.byKey(button));
          await tester.pumpAndSettle();
          expect(apps.added, isEmpty);
          expect(storage.confirmations, 0);
          expect(
            tester.widget<SecondaryButton>(find.byKey(button)).enabled,
            isFalse,
          );
          expect(
            find.text(
              browser
                  ? 'bypass_browser_warning_title'
                  : 'bypass_app_first_time_title',
            ),
            findsOneWidget,
          );
          await tester.tap(
            dialogAction(confirm ? (browser ? 'add_anyway' : 'add') : 'cancel'),
          );
          await tester.pumpAndSettle();
          expect(apps.added, confirm ? [path] : isEmpty);
          expect(storage.confirmations, confirm && !browser ? 1 : 0);
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            tester.widget<SecondaryButton>(find.byKey(button)).enabled,
            isTrue,
          );
        },
      );
    }
  }

  testWidgets('browser warning is shown again after confirming a bypass', (
    tester,
  ) async {
    final apps = _Apps();
    const path = r'C:\Browsers\Browser.exe';
    await _pumpPicker(
      tester,
      apps,
      () async => path,
      installed: const [
        AppData(name: 'Browser', bundleId: '', appPath: path, isBrowser: true),
      ],
    );
    for (final confirm in [true, false]) {
      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      expect(find.text('bypass_browser_warning_title'), findsOneWidget);
      await tester.tap(dialogAction(confirm ? 'add_anyway' : 'cancel'));
      await tester.pumpAndSettle();
      expect(apps.added, [path]);
    }
    expect(storage.confirmations, 0);
  });

  testWidgets('first-use confirmation is shared with manual selection', (
    tester,
  ) async {
    storage.seen = false;
    final apps = _Apps();
    const path = r'C:\Games\Game.exe';
    const app = AppData(name: 'Installed game', bundleId: '', appPath: path);
    await _pumpPicker(tester, apps, () async => path);
    final context = tester.element(find.byType(WindowsExecutablePicker));
    final pending = const AppsSplitTunneling().onTapAddApp(context, apps, app);
    await tester.pumpAndSettle();
    expect(find.text('bypass_app_first_time_title'), findsOneWidget);
    await tester.tap(dialogAction('add'));
    await tester.pumpAndSettle();
    await pending;
    expect(apps.toggled, [app]);

    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(apps.added, [path]);
    expect(storage.confirmations, 1);
  });

  testWidgets('browser metadata is matched by full path, not executable name', (
    tester,
  ) async {
    storage.seen = false;
    final apps = _Apps();
    await _pumpPicker(
      tester,
      apps,
      () async => r'C:\Games\Game.exe',
      installed: const [
        AppData(
          name: 'Browser',
          bundleId: '',
          appPath: r'C:\Browsers\Game.exe',
          isBrowser: true,
        ),
      ],
    );
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(find.text('bypass_app_first_time_title'), findsOneWidget);
    expect(find.text('bypass_browser_warning_title'), findsNothing);
    await tester.tap(dialogAction('cancel'));
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
  });

  testWidgets(
    'waits for discovery before deciding which confirmation to show',
    (tester) async {
      final apps = _Apps();
      final catalog = Completer<List<AppData>>();
      const path = r'C:\Browsers\Browser.exe';
      await _pumpPicker(
        tester,
        apps,
        () async => path,
        catalog: Stream.fromFuture(catalog.future),
      );
      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      expect(apps.added, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.widget<SecondaryButton>(find.byKey(button)).enabled,
        isFalse,
      );

      catalog.complete(const [
        AppData(name: 'Browser', bundleId: '', appPath: path, isBrowser: true),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('bypass_browser_warning_title'), findsOneWidget);
      expect(apps.added, isEmpty);
      await tester.tap(dialogAction('cancel'));
      await tester.pumpAndSettle();
      expect(apps.added, isEmpty);
      expect(
        tester.widget<SecondaryButton>(find.byKey(button)).enabled,
        isTrue,
      );
    },
  );

  testWidgets('discovery failure does not silently skip the browser warning', (
    tester,
  ) async {
    final apps = _Apps();
    final catalog = Completer<List<AppData>>();
    await _pumpPicker(
      tester,
      apps,
      () async => r'C:\Browsers\Browser.exe',
      catalog: Stream.fromFuture(catalog.future),
    );
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    catalog.completeError(StateError('discovery failed'));
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
    expect(find.text('unable_to_add_executable'), findsOneWidget);
    expect(tester.widget<SecondaryButton>(find.byKey(button)).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses discovery updates received while the file picker is open', (
    tester,
  ) async {
    final apps = _Apps();
    final catalog = StreamController<List<AppData>>();
    addTearDown(catalog.close);
    final selection = Completer<String?>();
    const path = r'C:\Browsers\Browser.exe';
    await _pumpPicker(
      tester,
      apps,
      () => selection.future,
      catalog: catalog.stream,
    );
    catalog.add(const []);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();

    catalog.add(const [
      AppData(name: 'Browser', bundleId: '', appPath: path, isBrowser: true),
    ]);
    await tester.pumpAndSettle();
    selection.complete(path);
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
    expect(find.text('bypass_browser_warning_title'), findsOneWidget);
    await tester.tap(dialogAction('cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'disposing during discovery does not show a dialog or add a rule',
    (tester) async {
      final apps = _Apps();
      final catalog = Completer<List<AppData>>();
      await _pumpPicker(
        tester,
        apps,
        () async => r'C:\Games\Game.exe',
        catalog: Stream.fromFuture(catalog.future),
      );
      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      catalog.complete(const []);
      await tester.pumpAndSettle();
      expect(apps.added, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissing the explanation does not add or mark it seen', (
    tester,
  ) async {
    storage.seen = false;
    final apps = _Apps();
    final navigatorKey = GlobalKey<NavigatorState>();
    await _pumpPicker(
      tester,
      apps,
      () async => r'C:\Games\Game.exe',
      navigatorKey: navigatorKey,
    );
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
    expect(storage.seen, isFalse);
    expect(storage.confirmations, 0);
    expect(tester.widget<SecondaryButton>(find.byKey(button)).enabled, isTrue);
  });

  testWidgets('disposing after confirmation does not add a rule', (
    tester,
  ) async {
    storage.seen = false;
    storage.pendingSave = Completer<void>();
    final apps = _Apps();
    await _pumpPicker(tester, apps, () async => r'C:\Games\Game.exe');
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    await tester.tap(dialogAction('add'));
    await tester.pumpAndSettle();
    expect(storage.confirmations, 1);
    expect(apps.added, isEmpty);
    await tester.pumpWidget(const SizedBox());
    storage.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(apps.added, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
