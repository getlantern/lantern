import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/share_my_connection/share_my_connection.dart';

// Reconciliation of ShareState against the peer client's real state. The
// peer-status stream is edge-triggered, so a UI that only listens opens at
// mode=off while SmC is already serving; adoptablePhase is the gate that
// decides when to correct that and when to stay put.
//
// Exercises adoptablePhase directly rather than syncFromBackend: the latter
// needs a WidgetRef, which a ProviderContainer cannot supply. The state
// write it guards is asserted separately below.
// ShareNotifier.build() reaches GetIt for the consent flag. Only
// containsKey is exercised; returning false means "consent never given",
// which keeps build() off the auto-enable reconciliation path.
class _FakeStorage implements LocalStorageService {
  @override
  bool containsKey(String key) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShareNotifier _notifier() {
  final container = ProviderContainer(
    overrides: [
      appSettingProvider.overrideWithValue(const AppSetting()),
    ],
  );
  addTearDown(container.dispose);
  return container.read(shareProvider.notifier);
}

void main() {
  setUp(() => sl.registerSingleton<LocalStorageService>(_FakeStorage()));
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
}
