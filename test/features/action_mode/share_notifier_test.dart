import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';

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
  _FakeStorage({this.consent = false});
  final bool consent;

  @override
  bool containsKey(String key) => consent && key == 'share_consent_acked';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeService implements LanternService {
  final calls = <String>[];

  @override
  Stream<AppEvent> watchAppEvents() => const Stream.empty();
  @override
  Future<Either<Failure, int>> getPeerManualPort() async {
    calls.add('manual_port');
    return right(0);
  }

  @override
  Future<Either<Failure, bool>> probeUPnP() async {
    calls.add('upnp');
    return right(false);
  }

  // Fails, so the start ends without touching app settings.
  @override
  Future<Either<Failure, Unit>> setUnboundedEnabled(bool enabled) async {
    calls.add('unbounded:$enabled');
    return left(Failure(error: 'test', localizedErrorMessage: 'test'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShareNotifier _notifier() => _setUp().$1;

(ShareNotifier, ProviderContainer, _FakeService) _setUp() {
  final service = _FakeService();
  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      appSettingProvider.overrideWithValue(const AppSetting()),
    ],
  );
  addTearDown(container.dispose);
  return (container.read(shareProvider.notifier), container, service);
}

/// A real WidgetRef over [container]: WidgetRef is sealed, so tests take one
/// from a Consumer.
Future<WidgetRef> _refFor(WidgetTester tester, ProviderContainer container) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (_, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

/// Consent given, so only the country decides.
Future<(ShareNotifier, WidgetRef, _FakeService)> _start(
  WidgetTester tester, {
  bool consent = true,
}) async {
  if (consent) {
    sl.unregister<LocalStorageService>();
    sl.registerSingleton<LocalStorageService>(_FakeStorage(consent: true));
  }
  final (notifier, container, service) = _setUp();
  return (notifier, await _refFor(tester, container), service);
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

  group('startForHelper', () {
    tearDown(() => CountryCode.update(''));

    testWidgets('does nothing without the sharing consent', (tester) async {
      CountryCode.update('DE');
      final (notifier, ref, service) = await _start(tester, consent: false);
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.probing, isFalse);
    });

    testWidgets('never auto-starts while the country is unknown', (
      tester,
    ) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.probing, isFalse);
    });

    testWidgets('never auto-starts in a censored country', (tester) async {
      CountryCode.update('IR');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.probing, isFalse);
    });

    testWidgets('starts as the toggle would in an uncensored country', (
      tester,
    ) async {
      CountryCode.update('DE');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      expect(service.calls, ['manual_port', 'upnp', 'unbounded:true']);
    });

    testWidgets('a start held back for an unknown country runs once it is '
        'known', (tester) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      CountryCode.update('DE');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, ['manual_port', 'upnp', 'unbounded:true']);
      // Once only.
      service.calls.clear();
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
    });

    testWidgets('a country change alone never starts sharing', (tester) async {
      CountryCode.update('DE');
      final (notifier, ref, service) = await _start(tester);
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
    });

    testWidgets('a held-back start stays held in a censored country', (
      tester,
    ) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      CountryCode.update('IR');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
    });
  });

  test('helperAutoStartAllowed mirrors lantern-cloud censoredCountries', () {
    expect(helperAutoStartAllowed(''), isFalse);
    for (final c in [
      'AE', 'AF', 'AZ', 'BY', 'CN', 'CU', 'EG', 'ET', 'IR', 'KP', //
      'MM', 'PK', 'RU', 'SA', 'SY', 'TJ', 'TM', 'UZ', 'VN', 'YE',
    ]) {
      expect(helperAutoStartAllowed(c), isFalse, reason: c);
      expect(helperAutoStartAllowed(c.toLowerCase()), isFalse, reason: c);
    }
    expect(CountryCode.helperCensoredCountries.length, 20);
    for (final c in ['DE', 'US', 'GB', 'TR']) {
      expect(helperAutoStartAllowed(c), isTrue, reason: c);
    }
  });
}
