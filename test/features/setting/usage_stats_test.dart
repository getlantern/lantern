import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide UsageStatsScreen;
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/usage_stats.dart';
import 'package:lantern/features/home/provider/data_cap_info_provider.dart';
import 'package:lantern/features/setting/provider/usage_stats_notifier.dart';
import 'package:lantern/features/setting/usage_stats.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:window_manager/window_manager.dart';

UsageTotals _totals({int proxyless = 0, int lantern = 0, int direct = 0}) =>
    UsageTotals({
      UsagePath.proxyless: UsageBytes(up: 0, down: proxyless),
      UsagePath.lantern: UsageBytes(up: 0, down: lantern),
      UsagePath.direct: UsageBytes(up: 0, down: direct),
    });

final _stats = UsageStats(
  since: DateTime(2026, 3, 4),
  month: '2026-11',
  thisMonth: _totals(proxyless: 1200000, lantern: 3400000),
  lifetime: _totals(proxyless: 56000000, lantern: 78000000, direct: 9000),
);

final _zero = UsageStats(
  since: DateTime(2026, 11, 21),
  month: '2026-11',
  thisMonth: const UsageTotals({}),
  lifetime: const UsageTotals({}),
  resetAt: DateTime(2026, 11, 21),
);

class _Service implements LanternService {
  _Service(this.stats);

  /// What each getUsageStats call returns, in turn; the last repeats.
  final List<Either<Failure, UsageStats>> stats;

  /// Reads, by index, that wait for their completer.
  final gates = <int, Completer<void>>{};
  Completer<void>? resetGate;
  Either<Failure, Unit> resetResult = right(unit);

  /// What reads return once a reset has run, if set.
  Either<Failure, UsageStats>? afterReset;
  int reads = 0;
  int resets = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<void> waitForRadiance() async {}

  @override
  Future<Either<Failure, UsageStats>> getUsageStats() async {
    final i = reads++;
    inFlight++;
    maxInFlight = max(maxInFlight, inFlight);
    try {
      await gates[i]?.future;
      if (resets > 0 && afterReset != null) return afterReset!;
      return stats[min(i, stats.length - 1)];
    } finally {
      inFlight--;
    }
  }

  @override
  Future<Either<Failure, Unit>> resetUsageStats() async {
    resets++;
    await resetGate?.future;
    return resetResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DataCap extends DataCapInfoNotifier {
  _DataCap(this.enabled);
  final bool enabled;

  @override
  Future<DataCapUsageResponse> build() async =>
      DataCapUsageResponse(enabled: enabled);
}

Future<void> _pump(
  WidgetTester tester,
  _Service service, {
  bool dataCap = false,
  bool settle = true,
}) async {
  // Tall enough that the lazy list builds every row.
  tester.view.physicalSize = const Size(393, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // Riverpod's automatic retry would make extra reads.
      retry: (_, _) => null,
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        dataCapInfoProvider.overrideWith(() => _DataCap(dataCap)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const UsageStatsScreen(),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final _failure = left<Failure, UsageStats>(
  Failure(error: 'boom', localizedErrorMessage: 'boom'),
);

Future<void> _tapReset(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('usage_stats.reset')),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byKey(const Key('usage_stats.reset')));
  await tester.pumpAndSettle();
}

Finder _inPath(UsagePath path, String text) => find.descendant(
  of: find.byKey(Key('usage_stats.path.${path.name}')),
  matching: find.text(text),
);

Finder _inTotal(String text) => find.descendant(
  of: find.byKey(const Key('usage_stats.total')),
  matching: find.text(text),
);

/// What the mocked window plugin reports.
var _windowVisible = true;
var _windowMinimized = false;
var _windowChecks = 0;

/// When set, the mocked isVisible waits for it.
Completer<void>? _windowGate;

void main() {
  setUpAll(Localization.loadTranslations);

  setUp(() {
    _windowVisible = true;
    _windowMinimized = false;
    _windowChecks = 0;
    _windowGate = null;
    PlatformUtils.debugIsDesktop = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          if (call.method == 'isVisible') await _windowGate?.future;
          return switch (call.method) {
            'isVisible' => (() {
              _windowChecks++;
              return _windowVisible;
            })(),
            'isMinimized' => _windowMinimized,
            _ => null,
          };
        });
  });

  tearDown(() {
    PlatformUtils.debugIsDesktop = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  testWidgets('opens on this month: month caption, total, every path, and '
      'the privacy note', (tester) async {
    await _pump(tester, _Service([right(_stats)]));

    expect(find.text('November 2026'), findsOneWidget);
    expect(_inTotal('4.6 MB'), findsOneWidget);
    expect(_inPath(UsagePath.proxyless, '1.2 MB'), findsOneWidget);
    expect(_inPath(UsagePath.lantern, '3.4 MB'), findsOneWidget);
    for (final path in UsagePath.values) {
      expect(find.byKey(Key('usage_stats.path.${path.name}')), findsOneWidget);
    }
    expect(_inPath(UsagePath.personal, '0 B'), findsOneWidget);
    expect(find.text('proxyless'.i18n), findsOneWidget);
    expect(find.text('usage_stats_direct'.i18n), findsOneWidget);
    expect(find.text('usage_stats_privacy'.i18n), findsOneWidget);
    expect(find.byKey(const Key('usage_stats.data_cap_note')), findsNothing);
  });

  testWidgets('All time shows lifetime totals since the start date', (
    tester,
  ) async {
    await _pump(tester, _Service([right(_stats)]));
    await tester.tap(find.byKey(const Key('usage_stats.all_time_tab')));
    await tester.pumpAndSettle();

    expect(
      find.text('usage_stats_since'.i18n.fill(['Mar 4, 2026'])),
      findsOneWidget,
    );
    expect(_inTotal('134 MB'), findsOneWidget);
    expect(_inPath(UsagePath.proxyless, '56 MB'), findsOneWidget);
    expect(_inPath(UsagePath.lantern, '78 MB'), findsOneWidget);
    expect(_inPath(UsagePath.direct, '9.0 kB'), findsOneWidget);
  });

  testWidgets('with a data cap, only Lantern Servers says it counts', (
    tester,
  ) async {
    await _pump(tester, _Service([right(_stats)]), dataCap: true);
    expect(
      _inPath(UsagePath.lantern, 'usage_stats_lantern_data_cap'.i18n),
      findsOneWidget,
    );
    expect(find.byKey(const Key('usage_stats.data_cap_note')), findsOneWidget);
  });

  testWidgets('Reset stats asks first, then resets and reloads', (
    tester,
  ) async {
    final service = _Service([right(_stats)])..afterReset = right(_zero);
    await _pump(tester, service);

    await tester.scrollUntilVisible(
      find.byKey(const Key('usage_stats.reset')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('usage_stats.reset')));
    await tester.pumpAndSettle();
    expect(find.text('usage_stats_reset_title'.i18n), findsOneWidget);
    await tester.tap(find.text('cancel'.i18n));
    await tester.pumpAndSettle();
    expect(service.resets, 0);
    expect(_inTotal('4.6 MB'), findsOneWidget);

    await tester.tap(find.byKey(const Key('usage_stats.reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('usage_stats_reset_confirm'.i18n));
    await tester.pumpAndSettle();
    expect(service.resets, 1);
    expect(find.text('usage_stats_reset_title'.i18n), findsNothing);
    expect(_inTotal('0 B'), findsOneWidget);
  });

  testWidgets('a failed load says so', (tester) async {
    await _pump(
      tester,
      _Service([left(Failure(error: 'boom', localizedErrorMessage: 'boom'))]),
    );
    expect(find.byKey(const Key('usage_stats.error')), findsOneWidget);
  });

  testWidgets('reloads while visible, including an inactive desktop window, '
      'and stops while the app is hidden', (tester) async {
    final service = _Service([right(_stats)]);
    await _pump(tester, service);
    expect(service.reads, 1);

    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(usageStatsRefreshInterval * 5);
    expect(service.reads, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.reads, 4, reason: 'coming back reloads at once');
    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 5);
  });

  testWidgets('stops while another route covers it, and reloads on return', (
    tester,
  ) async {
    final service = _Service([right(_stats)]);
    await _pump(tester, service);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await tester.pumpAndSettle();
    final covered = service.reads;
    await tester.pump(usageStatsRefreshInterval * 5);
    expect(service.reads, covered);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(service.reads, covered + 1);
  });

  testWidgets('a tick whose window check outlasts a covering route does not '
      'reload', (tester) async {
    final service = _Service([right(_stats)]);
    await _pump(tester, service);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final reads = service.reads;

    _windowGate = Completer<void>();
    await tester.pump(
      usageStatsRefreshInterval,
    ); // the tick waits on the window
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await tester.pumpAndSettle();
    _windowGate!.complete();
    await tester.pump();
    expect(
      service.reads,
      reads,
      reason: 'the covered screen stopped its timer',
    );
  });

  testWidgets('a tick while a reload runs does not start another', (
    tester,
  ) async {
    final service = _Service([right(_stats)])..gates[1] = Completer<void>();
    await _pump(tester, service);

    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 2);
    await tester.pump(usageStatsRefreshInterval * 3);
    expect(service.reads, 2);
    expect(service.maxInFlight, 1);

    service.gates[1]!.complete();
    await tester.pump();
    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 3);
  });

  testWidgets('a reload during the first load leaves the spinner alone', (
    tester,
  ) async {
    final service = _Service([right(_stats), _failure])
      ..gates[0] = Completer<void>();
    await _pump(tester, service, settle: false);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsageStatsScreen)),
    );
    await container.read(usageStatsProvider.notifier).refresh();
    await tester.pump();
    expect(find.byKey(const Key('usage_stats.error')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.gates[0]!.complete();
    await tester.pumpAndSettle();
    expect(service.reads, 1);
    expect(_inTotal('4.6 MB'), findsOneWidget);
  });

  testWidgets('Reset shows progress, and a failed reload after it says so', (
    tester,
  ) async {
    final service = _Service([right(_stats)])
      ..resetGate = Completer<void>()
      ..afterReset = _failure;
    await _pump(tester, service);

    await _tapReset(tester);
    await tester.tap(find.text('usage_stats_reset_confirm'.i18n));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('usage_stats.resetting')), findsOneWidget);
    final button = tester.widget<AppTextButton>(
      find.byKey(const Key('usage_stats.reset')),
    );
    expect(button.onPressed, isNull);

    service.resetGate!.complete();
    await tester.pumpAndSettle();
    expect(service.resets, 1);
    expect(find.byKey(const Key('usage_stats.error')), findsOneWidget);
    expect(_inTotal('4.6 MB'), findsNothing);
  });

  testWidgets('Retry after a failed load shows the spinner', (tester) async {
    final service = _Service([_failure, right(_stats)])
      ..gates[1] = Completer<void>();
    await _pump(tester, service);
    expect(find.byKey(const Key('usage_stats.error')), findsOneWidget);

    await tester.tap(find.text('retry'.i18n));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('usage_stats.error')), findsNothing);

    service.gates[1]!.complete();
    await tester.pumpAndSettle();
    expect(_inTotal('4.6 MB'), findsOneWidget);
  });

  testWidgets('stops while the window is closed to the tray, though the app '
      'stays inactive, and reloads when it comes back', (tester) async {
    final service = _Service([right(_stats)]);
    await _pump(tester, service);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(service.reads, 1);

    _windowVisible = false;
    await tester.pump(usageStatsRefreshInterval);
    await tester.pump(usageStatsRefreshInterval * 5);
    expect(service.reads, 1);

    _windowVisible = true;
    for (final listener in windowManager.listeners) {
      listener.onWindowFocus();
    }
    await tester.pump();
    expect(service.reads, 2, reason: 'coming back reloads at once');
    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 3);
  });

  testWidgets('a reset that failed but happened in the daemon counts', (
    tester,
  ) async {
    final service = _Service([right(_stats)])
      ..resetResult = _resetTimeout
      ..afterReset = right(_zero);
    await _pump(tester, service);
    await _tapReset(tester);
    await tester.tap(find.text('usage_stats_reset_confirm'.i18n));
    await tester.pumpAndSettle();
    expect(_inTotal('0 B'), findsOneWidget);
    expect(find.text('usage_stats_reset_failed'.i18n), findsNothing);
  });

  testWidgets('a reset that failed and did not happen says so', (tester) async {
    final service = _Service([right(_stats)])..resetResult = _resetTimeout;
    await _pump(tester, service);
    await _tapReset(tester);
    await tester.tap(find.text('usage_stats_reset_confirm'.i18n));
    await tester.pumpAndSettle();
    expect(service.reads, greaterThan(1), reason: 'reloads anyway');
    expect(_inTotal('4.6 MB'), findsOneWidget);
    expect(find.text('usage_stats_reset_failed'.i18n), findsOneWidget);
  });

  testWidgets('a window restored as a maximize reloads again', (tester) async {
    final service = _Service([right(_stats)]);
    await _pump(tester, service);
    _windowMinimized = true;
    await tester.pump(usageStatsRefreshInterval);
    await tester.pump(usageStatsRefreshInterval * 3);
    expect(service.reads, 1);

    _windowMinimized = false;
    for (final listener in windowManager.listeners) {
      listener.onWindowMaximize();
    }
    await tester.pump();
    expect(service.reads, 2);
    await tester.pump(usageStatsRefreshInterval);
    expect(service.reads, 3);
  });

  testWidgets('opened while the window is hidden, it does not reload until '
      'the window comes back', (tester) async {
    _windowVisible = false;
    final service = _Service([right(_stats)]);
    await _pump(tester, service);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsageStatsScreen)),
    );
    expect(container.read(usageStatsProvider).hasValue, isTrue);
    expect(_windowChecks, 1, reason: 'the window is checked on opening');
    await tester.pump(usageStatsRefreshInterval * 5);
    expect(service.reads, 1, reason: 'only the first load');

    _windowVisible = true;
    for (final listener in windowManager.listeners) {
      listener.onWindowFocus();
    }
    await tester.pump();
    expect(service.reads, 2);
  });

  group('notifier', () {
    ProviderContainer container(_Service service) {
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(c.dispose);
      c.listen(usageStatsProvider, (_, _) {});
      return c;
    }

    test('a reload started before a retry does not land over it', () async {
      final service = _Service([right(_stats), right(_zero), right(_stats)])
        ..gates[1] = Completer<void>()
        ..gates[2] = Completer<void>();
      final c = container(service);
      await c.read(usageStatsProvider.future);

      final stale = c.read(usageStatsProvider.notifier).refresh();
      await pumpEventQueue();
      expect(service.reads, 2);
      c.invalidate(usageStatsProvider);
      c.read(usageStatsProvider);
      await pumpEventQueue();
      expect(service.reads, 3);

      service.gates[1]!.complete();
      await stale;
      await pumpEventQueue();
      expect(c.read(usageStatsProvider).isLoading, isTrue);

      service.gates[2]!.complete();
      await pumpEventQueue();
      expect(c.read(usageStatsProvider).value?.resetAt, isNull);
    });

    test('no reload while a retry after a failed reset reload runs', () async {
      final service = _Service([right(_stats)])..afterReset = _failure;
      final c = container(service);
      await c.read(usageStatsProvider.future);
      await c.read(usageStatsProvider.notifier).reset();
      expect(c.read(usageStatsProvider).hasError, isTrue);

      service
        ..afterReset = null
        ..gates[service.reads] = Completer<void>();
      c.invalidate(usageStatsProvider);
      c.read(usageStatsProvider);
      await pumpEventQueue();
      final reads = service.reads;
      await c.read(usageStatsProvider.notifier).refresh();
      expect(service.reads, reads);
    });

    test(
      'leaving during the reload after a failed reset returns the failure',
      () async {
        final service = _Service([right(_stats)])
          ..resetResult = _resetTimeout
          ..gates[1] = Completer<void>();
        final c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [lanternServiceProvider.overrideWithValue(service)],
        );
        addTearDown(c.dispose);
        final sub = c.listen(usageStatsProvider, (_, _) {});
        await c.read(usageStatsProvider.future);

        final reset = c.read(usageStatsProvider.notifier).reset();
        await pumpEventQueue();
        expect(service.reads, 2, reason: 'the reload checking the reset runs');
        sub.close(); // the screen closes, so the notifier is disposed
        await pumpEventQueue();
        service.gates[1]!.complete();
        expect(await reset, _resetTimeout);
      },
    );
  });
}

final _resetTimeout = left<Failure, Unit>(
  Failure(error: 'deadline exceeded', localizedErrorMessage: 'timeout'),
);
