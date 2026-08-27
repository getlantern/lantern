import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/share_my_connection/share_my_connection.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

// Reconciliation of ShareState against the peer client's real state. The
// peer-status stream is edge-triggered, so a UI that only listens opens at
// mode=off while SmC is already serving; adoptablePhase is the gate that
// decides when to correct that and when to stay put.
//
// ShareNotifier.build() reaches GetIt for the consent flag. Only
// containsKey is exercised.
class _FakeStorage implements LocalStorageService {
  bool consentAcknowledged = false;

  @override
  bool containsKey(String key) => consentAcknowledged;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLanternService implements LanternService {
  final events = StreamController<AppEvent>.broadcast(sync: true);
  Completer<Either<Failure, String>>? pendingStatus;
  String status = '{"phase":"idle"}';
  int getStatusCalls = 0;
  int watchCalls = 0;
  int enableUnboundedCalls = 0;

  @override
  Future<Either<Failure, String>> getPeerStatusJSON() {
    getStatusCalls += 1;
    return pendingStatus?.future ?? Future.value(right(status));
  }

  @override
  Stream<AppEvent> watchAppEvents() {
    watchCalls += 1;
    return events.stream;
  }

  @override
  Future<Either<Failure, Unit>> setUnboundedEnabled(bool enabled) async {
    if (enabled) enableUnboundedCalls += 1;
    return right(unit);
  }

  void emitStatus(String phase) {
    events.add(
      AppEvent(eventType: 'peer-status', message: '{"phase":"$phase"}'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShareNotifier _notifier() {
  final container = ProviderContainer(
    overrides: [appSettingProvider.overrideWithValue(const AppSetting())],
  );
  addTearDown(container.dispose);
  return container.read(shareProvider.notifier);
}

void main() {
  late _FakeStorage storage;

  setUp(() {
    storage = _FakeStorage();
    sl.registerSingleton<LocalStorageService>(storage);
  });
  tearDown(() => sl.reset());

  group('adoptablePhase adopts', () {
    // Every phase that means sharing is genuinely up, including the
    // mid-flight ones — a UI that attached during registration should show
    // the real stage rather than waiting for the next transition.
    const up = {
      'mapping_port': SharePhase.mappingPort,
      'detecting_ip': SharePhase.detectingIp,
      'registering': SharePhase.registering,
      'starting_proxy': SharePhase.startingProxy,
      'verifying': SharePhase.verifying,
      'serving': SharePhase.serving,
    };

    up.forEach((wire, expected) {
      test(wire, () {
        expect(_notifier().adoptablePhase('{"phase":"$wire"}'), expected);
      });
    });
  });

  group('adoptablePhase declines', () {
    final cases = {
      'empty payload (could not ask)': '',
      'requireCore envelope': '{"error":"not_initialized"}',
      'malformed JSON': '{"phase":',
      'JSON that is not an object': '"serving"',
      'object with no phase key': '{"active":true}',
      'explicit null phase': '{"phase":null}',
      // idle is the backend agreeing we are off.
      'idle': '{"phase":"idle"}',
      // stopping is already tearing down; adopting it would show the card
      // coming up as it goes away.
      'stopping': '{"phase":"stopping"}',
      // error belongs to the toggle path, which owns the Unbounded fallback.
      'error': '{"phase":"error","error":"upnp failed"}',
      // fromWire maps anything unrecognized to idle, so a future phase this
      // build does not know must not be mistaken for "up".
      'unknown future phase': '{"phase":"teleporting"}',
    };

    cases.forEach((name, raw) {
      test(name, () {
        expect(_notifier().adoptablePhase(raw), isNull);
      });
    });
  });

  test('declining leaves ShareState untouched', () {
    final notifier = _notifier();
    final before = notifier.state;

    expect(notifier.adoptablePhase('{"error":"not_initialized"}'), isNull);

    // "not sharing" and "could not ask" must not render identically: an
    // unanswerable status leaves the UI exactly as it was.
    expect(notifier.state.mode, before.mode);
    expect(notifier.state.phase, before.phase);
    expect(notifier.state.active, before.active);
  });

  test('a serving payload carrying an empty error still adopts', () {
    // radiance tags Error omitempty so this should not occur on the wire,
    // but a payload that did carry it must not be mistaken for the
    // requireCore envelope — the phase is what decides.
    expect(
      _notifier().adoptablePhase('{"phase":"serving","error":""}'),
      SharePhase.serving,
    );
  });

  group('startup reconciliation', () {
    late _FakeLanternService service;
    late ProviderContainer container;

    setUp(() {
      storage.consentAcknowledged = true;
      service = _FakeLanternService();
      container = ProviderContainer(
        overrides: [
          lanternServiceProvider.overrideWithValue(service),
          appSettingProvider.overrideWithValue(
            const AppSetting(
              onboardingCompleted: true,
              unboundedAutoEnable: true,
            ),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await service.events.close();
    });

    test('persisted SmC wins over launch auto-start', () async {
      service.pendingStatus = Completer<Either<Failure, String>>();
      final notifier = container.read(shareProvider.notifier);

      final initialization = notifier.initializeFromBackend();
      expect(service.getStatusCalls, 1);
      expect(service.watchCalls, 1);
      expect(service.enableUnboundedCalls, 0);

      service.pendingStatus!.complete(right('{"phase":"serving"}'));
      await initialization;

      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.smc);
      expect(notifier.state.phase, SharePhase.serving);
      expect(service.enableUnboundedCalls, 0);
    });

    test('idle backend auto-starts Unbounded once', () async {
      final notifier = container.read(shareProvider.notifier);

      await notifier.initializeFromBackend();

      expect(service.getStatusCalls, 1);
      expect(service.watchCalls, 1);
      expect(service.enableUnboundedCalls, 1);
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    test('status event during snapshot request is not overwritten', () async {
      service.pendingStatus = Completer<Either<Failure, String>>();
      final notifier = container.read(shareProvider.notifier);

      final sync = notifier.syncFromBackend();
      service.emitStatus('serving');
      service.pendingStatus!.complete(right('{"phase":"registering"}'));
      await sync;

      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.smc);
      expect(notifier.state.phase, SharePhase.serving);
    });

    test(
      'concurrent reconciliation shares one request and subscription',
      () async {
        service.pendingStatus = Completer<Either<Failure, String>>();
        final notifier = container.read(shareProvider.notifier);

        final first = notifier.syncFromBackend();
        final second = notifier.syncFromBackend();

        expect(service.getStatusCalls, 1);
        expect(service.watchCalls, 1);
        service.pendingStatus!.complete(right('{"phase":"idle"}'));
        await Future.wait([first, second]);
      },
    );
  });
}
