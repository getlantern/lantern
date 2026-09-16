import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern/core/models/action_mode_connection_event.dart';
import 'package:lantern/core/services/geo_lookup_service.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class FakeStorage implements LocalStorageService {
  @override
  bool containsKey(String key) => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeService implements LanternService {
  final enableResult = Completer<Either<Failure, Unit>>();
  int enableCalls = 0;
  @override
  Future<Either<Failure, int>> getPeerManualPort() async => right(1);
  Future<Either<Failure, Unit>>? Function(bool enabled)? onSetUnbounded;
  @override
  Future<Either<Failure, Unit>> setUnboundedEnabled(bool enabled) {
    enableCalls++;
    return onSetUnbounded?.call(enabled) ?? enableResult.future;
  }

  final events = StreamController<AppEvent>.broadcast(sync: true);
  @override
  Stream<AppEvent> watchAppEvents() => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettings extends AppSettingNotifier {
  @override
  AppSetting build() => const AppSetting(unboundedTotalHelped: 10);
  @override
  void setUnboundedTotalHelped(int value) {
    state = state.copyWith(unboundedTotalHelped: value);
  }
}

class FakeRadianceSettings extends RadianceSettings {
  final startResult = Completer<Either<Failure, Unit>>();
  @override
  RadianceSettingsState build() => const RadianceSettingsState();
  Future<Either<Failure, Unit>>? Function(bool value)? onSetPeerProxy;
  @override
  Future<Either<Failure, Unit>> setPeerProxy(bool value) =>
      onSetPeerProxy?.call(value) ?? startResult.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeService service;
  late ProviderContainer container;
  setUp(() async {
    await sl.reset();
    GeoLookupService.resetCacheForTest();
    await http.runWithClient(
      () => Future.wait(
        [
          '192.0.2.1',
          '192.0.2.2',
          '192.0.2.251',
        ].map(GeoLookupService.peerLookup),
      ),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'Country': {
              'IsoCode': 'US',
              'Names': {'en': 'United States'},
            },
          }),
          200,
        ),
      ),
    );
    sl.registerSingleton<LocalStorageService>(FakeStorage());
    service = FakeService();
    container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWith(FakeSettings.new),
        radianceSettingsProvider.overrideWith(FakeRadianceSettings.new),
      ],
    );
    container.read(shareProvider);
  });
  tearDown(() async {
    container.dispose();
    await service.events.close();
    await sl.reset();
  });
  Future<void> snapshot(
    bool enabled,
    bool running,
    List<String> peers, {
    int arrivals = 2,
    String epoch = "run-1",
  }) async {
    service.events.add(
      AppEvent(
        eventType: 'unbounded-snapshot',
        message: jsonEncode({
          'epoch': epoch,
          'arrivals': arrivals,
          'enabled': enabled,
          'running': running,
          'peers': peers,
        }),
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'restores a running backend without recounting lifetime arrivals',
    () async {
      await snapshot(true, true, ['192.0.2.1', '192.0.2.1', '192.0.2.2']);
      final state = container.read(shareProvider);
      expect(state.active, true);
      expect(state.unboundedRunning, true);
      expect(state.mode, ShareMode.unbounded);
      expect(state.activeCount, 2);
      expect(state.totalCount, 10);
      await snapshot(true, true, ['192.0.2.1', '192.0.2.2']);
      expect(container.read(shareProvider).activeCount, 2);
      expect(container.read(shareProvider).totalCount, 10);
    },
  );
  test('reconciles missed disconnects and new arrivals idempotently', () async {
    await snapshot(true, true, ['192.0.2.1']);
    await snapshot(true, true, ['192.0.2.2'], arrivals: 3);
    expect(container.read(shareProvider).activeCount, 1);
    expect(container.read(shareProvider).totalCount, 11);
    await snapshot(true, true, ['192.0.2.2'], arrivals: 3);
    expect(container.read(shareProvider).totalCount, 11);
    await snapshot(true, true, [], arrivals: 3);
    expect(container.read(shareProvider).activeCount, 0);
  });
  test(
    'enabled is distinct from running and backend stop clears peers',
    () async {
      await snapshot(true, true, ['192.0.2.1']);
      await snapshot(true, false, []);
      expect(container.read(shareProvider).active, true);
      expect(container.read(shareProvider).unboundedRunning, false);
      expect(container.read(shareProvider).activeCount, 0);
      await snapshot(false, false, []);
      expect(container.read(shareProvider).active, false);
      expect(container.read(shareProvider).mode, ShareMode.off);
    },
  );
  test(
    'counts connections completed between snapshots and rebases after restart',
    () async {
      await snapshot(true, true, [], arrivals: 4);
      await snapshot(true, true, [], arrivals: 7);
      expect(container.read(shareProvider).totalCount, 13);
      await snapshot(true, true, [], arrivals: 1, epoch: 'run-2');
      expect(container.read(shareProvider).totalCount, 13);
    },
  );
  test('backend loss clears stale running status and peers', () async {
    await snapshot(true, true, ['192.0.2.1']);
    service.events.add(
      AppEvent(eventType: 'unbounded-unavailable', message: '{}'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(shareProvider).unboundedRunning, false);
    expect(container.read(shareProvider).activeCount, 0);
    await snapshot(true, true, ['192.0.2.1']);
    expect(container.read(shareProvider).activeCount, 1);
    expect(container.read(shareProvider).totalCount, 10);
  });
  test('recovered peers replay without a new-arrival animation', () async {
    const ip = '192.0.2.251';
    final events = <ActionModeConnectionEvent>[];
    final sub = container
        .read(shareProvider.notifier)
        .connectionEvents
        .listen(events.add);
    addTearDown(sub.cancel);
    await snapshot(true, true, []);
    await snapshot(true, true, [ip], arrivals: 3);
    expect(events.last.state, 1);
    expect(events.last.isReplay, false);
    final originalWorker = events.last.workerIdx;
    service.events.add(
      AppEvent(eventType: 'unbounded-unavailable', message: '{}'),
    );
    await snapshot(true, true, [ip], arrivals: 3);
    expect(events.last.state, 1);
    expect(events.last.isReplay, true);
    expect(events.last.workerIdx, greaterThan(originalWorker));
    expect(container.read(shareProvider).totalCount, 11);
  });

  testWidgets('pending auto-start ignores failure after disposal', (
    tester,
  ) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (ctx, ref, child) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    final starting = container
        .read(shareProvider.notifier)
        .autoStart(widgetRef);
    expect(service.enableCalls, 1);
    container.invalidate(shareProvider);
    await tester.runAsync(() async {
      service.enableResult.complete(
        left(Failure(error: 'offline', localizedErrorMessage: 'offline')),
      );
      await starting;
    });
  });

  testWidgets('pending fallback ignores failures after disposal', (
    tester,
  ) async {
    late WidgetRef widgetRef;
    late BuildContext context;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (ctx, ref, child) {
            widgetRef = ref;
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    final radiance =
        container.read(radianceSettingsProvider.notifier)
            as FakeRadianceSettings;
    final starting = container
        .read(shareProvider.notifier)
        .toggle(context, widgetRef);
    await tester.pump();
    service.events.add(
      AppEvent(
        eventType: 'peer-status',
        message: jsonEncode({'phase': 'error', 'error': 'port unreachable'}),
      ),
    );
    await tester.pump();
    expect(service.enableCalls, 1);
    container.invalidate(shareProvider);
    final failure = left<Failure, Unit>(
      Failure(error: 'offline', localizedErrorMessage: 'offline'),
    );
    await tester.runAsync(() async {
      service.enableResult.complete(failure);
      radiance.startResult.complete(failure);
      await starting;
    });
    await tester.pump();
  });

  testWidgets('fallback clears peers and serializes snapshots and toggles', (
    tester,
  ) async {
    late WidgetRef widgetRef;
    late BuildContext context;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (ctx, ref, child) {
            widgetRef = ref;
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    final notifier = container.read(shareProvider.notifier);
    final starting = notifier.toggle(context, widgetRef);
    await tester.pump();
    service.events.add(
      AppEvent(
        eventType: 'peer-connection',
        message: jsonEncode({'state': 1, 'source': '192.0.2.1:1234'}),
      ),
    );
    await tester.pump();
    expect(container.read(shareProvider).activeCount, 1);
    service.events.add(
      AppEvent(
        eventType: 'peer-status',
        message: jsonEncode({'phase': 'error', 'error': 'port unreachable'}),
      ),
    );
    await tester.pump();
    expect(container.read(shareProvider).mode, ShareMode.unbounded);
    expect(container.read(shareProvider).activeCount, 0);
    service.events.add(
      AppEvent(
        eventType: 'unbounded-snapshot',
        message: jsonEncode({
          'enabled': false,
          'running': false,
          'peers': [],
          'epoch': 'run-1',
          'arrivals': 0,
        }),
      ),
    );
    await tester.pump();
    await notifier.toggle(context, widgetRef);
    expect(service.enableCalls, 1);
    expect(container.read(shareProvider).mode, ShareMode.unbounded);
    await tester.runAsync(() async {
      service.enableResult.complete(right(unit));
      (container.read(radianceSettingsProvider.notifier)
              as FakeRadianceSettings)
          .startResult
          .complete(right(unit));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump();
    await starting;
    service.events.add(
      AppEvent(
        eventType: 'unbounded-snapshot',
        message: jsonEncode({
          'enabled': true,
          'running': true,
          'peers': ['192.0.2.1'],
          'epoch': 'run-1',
          'arrivals': 1,
        }),
      ),
    );
    await tester.pump();
    expect(container.read(shareProvider).activeCount, 1);
    expect(container.read(shareProvider).unboundedRunning, true);
  });

  for (final smc in [false, true]) {
    testWidgets(
      'a failed stop keeps ${smc ? 'SmC' : 'Unbounded'} reported on',
      (tester) async {
        late WidgetRef widgetRef;
        late BuildContext context;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (ctx, ref, child) {
                widgetRef = ref;
                context = ctx;
                return const SizedBox();
              },
            ),
          ),
        );
        final radiance =
            container.read(radianceSettingsProvider.notifier)
                as FakeRadianceSettings;
        final failure = left<Failure, Unit>(
          Failure(error: 'backend busy', localizedErrorMessage: 'backend busy'),
        );
        service.onSetUnbounded = (enabled) async =>
            enabled ? right(unit) : failure;
        radiance.onSetPeerProxy = (value) async =>
            value ? right(unit) : failure;
        final notifier = container.read(shareProvider.notifier);
        if (smc) {
          // Manual port (FakeService returns 1) routes the start to SmC.
          await notifier.toggle(context, widgetRef);
          expect(container.read(shareProvider).mode, ShareMode.smc);
        } else {
          // snapshot() sleeps on a real timer; under testWidgets pump instead.
          service.events.add(
            AppEvent(
              eventType: 'unbounded-snapshot',
              message: jsonEncode({
                'epoch': 'run-1',
                'arrivals': 1,
                'enabled': true,
                'running': true,
                'peers': ['192.0.2.1'],
              }),
            ),
          );
          await tester.pump();
          expect(container.read(shareProvider).mode, ShareMode.unbounded);
        }
        await notifier.toggle(context, widgetRef);
        final state = container.read(shareProvider);
        expect(state.active, isTrue, reason: 'backend refused to stop');
        expect(state.mode, smc ? ShareMode.smc : ShareMode.unbounded);
        expect(state.errorMessage, 'backend busy');
        // A later successful stop clears it.
        service.onSetUnbounded = (_) async => right(unit);
        radiance.onSetPeerProxy = (_) async => right(unit);
        await notifier.toggle(context, widgetRef);
        expect(container.read(shareProvider).active, isFalse);
        expect(container.read(shareProvider).errorMessage, isNull);
      },
    );
  }
}
