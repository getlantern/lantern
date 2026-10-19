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
import 'package:lantern/core/models/relay_stats.dart';
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
  int relayWrites = 0;
  @override
  AppSetting build() => seed;

  static const seed = AppSetting(
    unboundedTotalHelped: 10,
    unboundedBytesDown: 1000000,
    unboundedBytesUp: 2000,
    unboundedCountryStats: {
      'US': RelayCountryStats(
        code: 'US',
        name: 'United States',
        down: 900,
        people: 2,
      ),
    },
  );
  @override
  void setUnboundedTotalHelped(int value) {
    state = state.copyWith(unboundedTotalHelped: value);
  }

  @override
  void setUnboundedRelayStats({
    required int bytesDown,
    required int bytesUp,
    required Map<String, RelayCountryStats> countries,
    ({String epoch, int down, int up})? mark,
  }) {
    relayWrites++;
    state = state.copyWith(
      unboundedBytesDown: bytesDown,
      unboundedBytesUp: bytesUp,
      unboundedCountryStats: countries,
      unboundedRelayEpoch: mark?.epoch,
      unboundedRelayMarkDown: mark?.down,
      unboundedRelayMarkUp: mark?.up,
    );
  }
}

class ResumingSettings extends FakeSettings {
  @override
  AppSetting build() => FakeSettings.seed.copyWith(
    unboundedRelayEpoch: 'run-1',
    unboundedRelayMarkDown: 4000,
    unboundedRelayMarkUp: 400,
  );
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

const unknownIp = '198.51.100.9';

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
          unknownIp,
        ].map(GeoLookupService.peerLookup),
      ),
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({
            'Country': {
              'IsoCode': request.url.path.endsWith(unknownIp) ? '' : 'US',
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
    Map<String, Object> bytes = const {},
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
          ...bytes,
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

  group('relay stats', () {
    late DateTime now;
    late FakeSettings settings;
    setUp(() {
      now = DateTime(2026, 10, 17);
      container.read(shareProvider.notifier).clock = () => now;
      settings = container.read(appSettingProvider.notifier) as FakeSettings;
    });
    Map<String, Object> counters(
      int down,
      int up,
      Map<String, (int, int)> peers,
    ) => {
      'bytesDown': down,
      'bytesUp': up,
      'peerBytes': [
        for (final e in peers.entries)
          {'ip': e.key, 'down': e.value.$1, 'up': e.value.$2},
      ],
    };
    Future<void> tick(
      int down,
      int up,
      Map<String, (int, int)> peers, {
      List<String> present = const ['192.0.2.1'],
      String epoch = 'run-1',
    }) async {
      now = now.add(const Duration(seconds: 1));
      await snapshot(
        true,
        true,
        present,
        epoch: epoch,
        bytes: counters(down, up, peers),
      );
    }

    RelayStats relay() => container.read(shareProvider).relay;

    test('seeds lifetime totals from settings', () {
      expect(relay().lifetimeDown, 1000000);
      expect(relay().lifetimeUp, 2000);
      expect(relay().countries['US']!.people, 2);
      expect(relay().available, isFalse);
    });

    test('baseline, deltas, speed, and per-country attribution', () async {
      // Counters already accumulated before this app run are not recounted.
      await tick(5000, 500, {'192.0.2.1': (5000, 500)});
      expect(relay().available, isTrue);
      expect(relay().sessionBytes, 0);
      expect(relay().lifetimeDown, 1000000);
      expect(relay().speedDown, 0);

      // 192.0.2.1 keeps going; the unknown peer came and went between
      // snapshots and only shows up in peerBytes.
      await tick(7000, 700, {'192.0.2.1': (6500, 650), unknownIp: (500, 50)});
      expect(relay().sessionDown, 2000);
      expect(relay().sessionUp, 200);
      expect(relay().lifetimeDown, 1002000);
      expect(relay().lifetimeUp, 2200);
      expect(relay().speedDown, 1000);
      expect(relay().speedUp, 100);
      final us = relay().countries['US']!;
      expect((us.down, us.up, us.people), (2400, 150, 2));
      final unknown = relay().countries[RelayCountryStats.unknownCode]!;
      expect((unknown.down, unknown.up, unknown.people), (500, 50, 1));
      expect(unknown.isUnknown, isTrue);

      // A new US arrival counts a person even before it moves bytes.
      await tick(
        7000,
        700,
        {'192.0.2.1': (6500, 650), unknownIp: (500, 50)},
        present: ['192.0.2.1', '192.0.2.2'],
      );
      expect(relay().countries['US']!.people, 3);
      expect(relay().speedDown, 500);
    });

    test('counter resets and new epochs count from zero', () async {
      await tick(5000, 500, {'192.0.2.1': (5000, 500)});
      await tick(100, 600, {'192.0.2.1': (100, 600)});
      expect(relay().sessionDown, 100);
      expect(relay().sessionUp, 600);
      // A reset is not a rate over one interval, so speed does not spike.
      expect(relay().speedDown, 0);
      await tick(300, 30, {'192.0.2.2': (300, 30)}, epoch: 'run-2');
      expect(relay().sessionDown, 400);
      expect(relay().sessionUp, 630);
      expect(relay().countries['US']!.down, 900 + 100 + 300);
    });

    test('persists on a throttle and when sharing stops', () async {
      // The baseline moves no bytes but saves its watermark.
      await tick(0, 0, {});
      expect(settings.relayWrites, 1);
      expect(container.read(appSettingProvider).unboundedRelayEpoch, 'run-1');
      await tick(0, 0, {});
      expect(settings.relayWrites, 1);
      now = now.add(const Duration(seconds: 30));
      await tick(1000, 0, {'192.0.2.1': (1000, 0)});
      expect(settings.relayWrites, greaterThanOrEqualTo(1));
      final writes = settings.relayWrites;
      await tick(2000, 0, {'192.0.2.1': (2000, 0)});
      await tick(3000, 0, {'192.0.2.1': (3000, 0)});
      expect(settings.relayWrites, writes);
      now = now.add(const Duration(seconds: 30));
      await tick(4000, 0, {'192.0.2.1': (4000, 0)});
      expect(settings.relayWrites, writes + 1);
      expect(container.read(appSettingProvider).unboundedBytesDown, 1004000);
      expect(container.read(appSettingProvider).unboundedRelayMarkDown, 4000);
      expect(container.read(appSettingProvider).unboundedRelayEpoch, 'run-1');
      await tick(5000, 0, {'192.0.2.1': (5000, 0)});
      service.events.add(
        AppEvent(eventType: 'unbounded-unavailable', message: '{}'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(settings.relayWrites, writes + 2);
      expect(container.read(appSettingProvider).unboundedBytesDown, 1005000);
      expect(relay().speedDown, 0);
    });

    test('a stopped snapshot saves its final counters at once', () async {
      await tick(0, 0, {});
      await tick(1000, 0, {'192.0.2.1': (1000, 0)});
      final writes = settings.relayWrites;
      now = now.add(const Duration(seconds: 1));
      await snapshot(
        false,
        false,
        [],
        bytes: counters(1500, 0, {'192.0.2.1': (1500, 0)}),
      );
      expect(settings.relayWrites, writes + 1);
      expect(container.read(appSettingProvider).unboundedBytesDown, 1001500);
      expect(container.read(appSettingProvider).unboundedRelayMarkDown, 1500);
    });

    test('a throttled save is deferred, not dropped', () async {
      container.read(shareProvider.notifier)
        ..relayPersistInterval = const Duration(milliseconds: 50)
        ..clock = DateTime.now;
      await tick(0, 0, {});
      await tick(1000, 0, {'192.0.2.1': (1000, 0)});
      final writes = settings.relayWrites;
      await tick(2000, 0, {'192.0.2.1': (2000, 0)});
      expect(settings.relayWrites, writes);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(settings.relayWrites, writes + 1);
      expect(container.read(appSettingProvider).unboundedBytesDown, 1002000);
    });

    test('resumes from the persisted watermark after an app restart', () async {
      final resumed = ProviderContainer(
        overrides: [
          lanternServiceProvider.overrideWithValue(service),
          appSettingProvider.overrideWith(ResumingSettings.new),
          radianceSettingsProvider.overrideWith(FakeRadianceSettings.new),
        ],
      );
      addTearDown(resumed.dispose);
      resumed.read(shareProvider);
      await snapshot(true, true, [
        '192.0.2.1',
      ], bytes: counters(6000, 500, {'192.0.2.1': (6000, 500)}));
      final relay = resumed.read(shareProvider).relay;
      expect(relay.lifetimeDown, 1000000 + 2000);
      expect(relay.lifetimeUp, 2000 + 100);
      // Peer counters only set a baseline, so per-country totals hold.
      expect(relay.countries['US']!.down, 900);
    });

    test(
      'snapshots without byte counters (older radiance) are tolerated',
      () async {
        await snapshot(true, true, ['192.0.2.1']);
        await snapshot(true, true, ['192.0.2.1', '192.0.2.2']);
        expect(relay().available, isFalse);
        expect(relay().sessionBytes, 0);
        expect(relay().lifetimeDown, 1000000);
        expect(relay().countries['US']!.people, 3);
      },
    );
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
    // SmC peers count toward their country too, with no bytes.
    final us = container.read(shareProvider).relay.countries['US']!;
    expect(us.people, 3);
    expect(us.down, 900);
    service.events.add(
      AppEvent(
        eventType: 'peer-status',
        message: jsonEncode({'phase': 'error', 'error': 'port unreachable'}),
      ),
    );
    await tester.pump();
    expect(container.read(shareProvider).mode, ShareMode.unbounded);
    expect(container.read(shareProvider).activeCount, 0);
    expect(container.read(shareProvider).fallbackReason, 'port unreachable');
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

  testWidgets('counts final Unbounded bytes that arrive during SmC', (
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
    service.onSetUnbounded = (_) async => right(unit);
    radiance.onSetPeerProxy = (_) async => right(unit);
    Future<void> emit(bool on, int down) async {
      service.events.add(
        AppEvent(
          eventType: 'unbounded-snapshot',
          message: jsonEncode({
            'epoch': 'run-1',
            'arrivals': 1,
            'enabled': on,
            'running': on,
            'peers': on ? ['192.0.2.1'] : [],
            'bytesDown': down,
            'bytesUp': 0,
            'peerBytes': [
              {'ip': '192.0.2.1', 'down': down, 'up': 0},
            ],
          }),
        ),
      );
      await tester.pump();
    }

    await emit(true, 0);
    await emit(true, 1000);
    final notifier = container.read(shareProvider.notifier);
    // Stop Unbounded, then start SmC before the backend's final snapshot.
    await notifier.toggle(context, widgetRef);
    await notifier.toggle(context, widgetRef);
    expect(container.read(shareProvider).mode, ShareMode.smc);
    await emit(false, 1500);
    final state = container.read(shareProvider);
    expect(state.mode, ShareMode.smc);
    expect(state.active, isTrue);
    expect(state.relay.lifetimeDown, 1001500);
    final saved = container.read(appSettingProvider);
    expect(saved.unboundedBytesDown, 1001500);
    expect(saved.unboundedRelayMarkDown, 1500);
  });
}
