import 'dart:async';

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
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';

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

  final events = StreamController<AppEvent>.broadcast();

  @override
  Stream<AppEvent> watchAppEvents() => events.stream;
  int manualPort = 0;
  void Function()? onManualPort;

  @override
  Future<Either<Failure, int>> getPeerManualPort() async {
    calls.add('manual_port');
    onManualPort?.call();
    return right(manualPort);
  }

  /// radiance's persisted Unbounded opt-in.
  bool unboundedEnabled = false;

  @override
  Future<Either<Failure, bool>> isUnboundedEnabled() async {
    calls.add('unbounded?');
    return right(unboundedEnabled);
  }

  /// The raw peer status syncFromBackend reads; empty means not sharing.
  String peerStatus = '';

  @override
  Future<Either<Failure, String>> getPeerStatusJSON() async =>
      right(peerStatus);

  bool peerOk = true;

  @override
  Future<Either<Failure, Unit>> setPeerProxyEnabled(bool enabled) async {
    calls.add('peer:$enabled');
    if (peerOk) return right(unit);
    return left(Failure(error: 'no upnp', localizedErrorMessage: 'no upnp'));
  }

  /// Runs during the UPnP probe, as a country change can.
  void Function()? onProbe;

  @override
  Future<Either<Failure, bool>> probeUPnP() async {
    calls.add('upnp');
    onProbe?.call();
    return right(false);
  }

  /// When set, setUnboundedEnabled waits for it, holding a start in flight.
  Completer<void>? unboundedGate;

  /// By default Unbounded fails to start, so a start ends without touching
  /// app settings.
  bool unboundedOk = false;

  @override
  Future<Either<Failure, Unit>> setUnboundedEnabled(bool enabled) async {
    calls.add('unbounded:$enabled');
    await unboundedGate?.future;
    if (unboundedOk) return right(unit);
    return left(Failure(error: 'test', localizedErrorMessage: 'test'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShareNotifier _notifier() => _setUp().$1;

/// The view [_Helpers.helpsSomeone] loads: true helps a friend, false helps
/// nobody, null fails to load.
bool? _helps = false;

/// When set, helpsSomeone waits for it, as behind a launch refresh.
Completer<void>? _helpsGate;

/// The people this device helps, as an approval leaves them: one friend.
class _Helpers extends HelpersNotifier {
  @override
  HelpersState build() => const HelpersState(
    view: HelpersView(helping: [HelperPairingView(pairingId: 'p1')]),
  );

  int helpsAsked = 0;

  @override
  bool get used => true;

  /// Loads the [_helps] view, unless a newer one was applied meanwhile, as
  /// the real notifier drops an out-of-order view.
  @override
  Future<bool?> helpsSomeone() async {
    helpsAsked++;
    await _helpsGate?.future;
    if (_helps != null && !state.viewLoaded) {
      state = state.copyWith(
        viewLoaded: true,
        view: HelpersView(
          helping: [if (_helps!) const HelperPairingView(pairingId: 'p1')],
        ),
      );
    }
    return helpsSomeoneNow;
  }

  void helpNobody() =>
      state = state.copyWith(view: const HelpersView(unlocked: true));

  /// A newly approved pairing, as a refresh applies it.
  void helpSomeone() => state = state.copyWith(
    viewLoaded: true,
    view: const HelpersView(helping: [HelperPairingView(pairingId: 'p2')]),
  );
}

AppSetting _appSetting = const AppSetting();

class _Settings extends AppSettingNotifier {
  @override
  AppSetting build() => _appSetting;
  @override
  void setUnboundedSessionCount(int value) {}

  void set(AppSetting value) => state = value;
}

/// Skips the settings fetch the real build starts.
class _Radiance extends RadianceSettings {
  @override
  RadianceSettingsState build() => const RadianceSettingsState();
}

(ShareNotifier, ProviderContainer, _FakeService) _setUp() {
  final service = _FakeService();
  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      appSettingProvider.overrideWith(_Settings.new),
      helpersProvider.overrideWith(_Helpers.new),
      radianceSettingsProvider.overrideWith(_Radiance.new),
    ],
  );
  addTearDown(container.dispose);
  return (container.read(shareProvider.notifier), container, service);
}

/// A real WidgetRef over [container]: WidgetRef is sealed, so tests take one
/// from a Consumer.
BuildContext? _context;

Future<WidgetRef> _refFor(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          _context = context;
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
  setUp(() {
    _appSetting = const AppSetting();
    _helps = false;
    _helpsGate = null;
    sl.registerSingleton<LocalStorageService>(_FakeStorage());
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

    testWidgets('a manual toggle cancels a held-back start', (tester) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      service.unboundedOk = true;
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isTrue);
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isFalse);
      service.calls.clear();
      CountryCode.update('DE');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isFalse);
    });

    testWidgets('a held-back start is dropped once this device helps nobody', (
      tester,
    ) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      (ref.read(helpersProvider.notifier) as _Helpers).helpNobody();
      CountryCode.update('DE');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.probing, isFalse);
    });

    testWidgets('a held-back start is not run for a pairing already gone', (
      tester,
    ) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      (ref.read(helpersProvider.notifier) as _Helpers).helpNobody();
      // An approval counted after a newer view already dropped the pairing.
      await notifier.startForHelper(ref);
      CountryCode.update('DE');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
    });

    testWidgets('a late approval after the pairing ended never starts', (
      tester,
    ) async {
      CountryCode.update('DE');
      final (notifier, ref, service) = await _start(tester);
      service.unboundedOk = true;
      (ref.read(helpersProvider.notifier) as _Helpers).helpNobody();
      // An older view's new_helping, counted after a newer empty view.
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.probing, isFalse);
      // Nothing was kept pending either: a later, unrelated pairing does not
      // start it on a country change.
      (ref.read(helpersProvider.notifier) as _Helpers).helpSomeone();
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, isEmpty);
    });

    testWidgets('a retry skipped while another start is in flight keeps the '
        'held-back start', (tester) async {
      CountryCode.update('');
      final (notifier, ref, service) = await _start(tester);
      await notifier.startForHelper(ref);
      expect(service.calls, isEmpty);
      service.unboundedGate = Completer<void>();
      final other = notifier.autoStart(ref);
      await tester.pump();
      CountryCode.update('DE');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, ['unbounded:true'], reason: 'the retry is skipped');
      service.unboundedGate!.complete();
      await other;
      expect(notifier.state.active, isFalse);
      service.calls.clear();
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, ['manual_port', 'upnp', 'unbounded:true']);
    });

    testWidgets('a country that becomes unknown during the network checks '
        'stops the start before the backend', (tester) async {
      CountryCode.update('DE');
      final (notifier, ref, service) = await _start(tester);
      service.unboundedOk = true;
      service.onProbe = () => CountryCode.update('');
      await notifier.startForHelper(ref);
      expect(service.calls, ['manual_port', 'upnp']);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.probing, isFalse);
      service.onProbe = null;
      service.calls.clear();
      CountryCode.update('DE');
      await notifier.retryPendingHelperStart(ref);
      expect(service.calls, ['manual_port', 'upnp', 'unbounded:true']);
      expect(notifier.state.active, isTrue);
    });

    testWidgets('a pairing that ends during the network checks stops the '
        'start before the backend', (tester) async {
      CountryCode.update('DE');
      final (notifier, ref, service) = await _start(tester);
      service.onProbe = () =>
          (ref.read(helpersProvider.notifier) as _Helpers).helpNobody();
      await notifier.startForHelper(ref);
      expect(service.calls, ['manual_port', 'upnp']);
      expect(notifier.state.probing, isFalse);
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

  group('reconcileLaunch', () {
    const autoOn = AppSetting(
      onboardingCompleted: true,
      unboundedAutoEnable: true,
    );
    const autoOff = AppSetting(onboardingCompleted: true);

    /// Home's launch sequence: sync, reconcile, then the auto-start gate.
    Future<void> launch(ShareNotifier notifier, WidgetRef ref) async {
      await notifier.syncFromBackend(ref);
      await notifier.reconcileLaunch(ref);
      final s = _appSetting;
      if (s.unboundedHidden || !s.onboardingCompleted) return;
      if (!s.unboundedAutoEnable) return;
      if (notifier.state.active || notifier.state.probing) return;
      await notifier.autoStart(ref);
    }

    _Helpers helpers(WidgetRef ref) =>
        ref.read(helpersProvider.notifier) as _Helpers;

    testWidgets('stops a resumed Unbounded session when auto-enable is off', (
      tester,
    ) async {
      _appSetting = autoOff;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?', 'manual_port', 'unbounded:false']);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.mode, ShareMode.off);
    });

    testWidgets('stops a resumed session when the tab is hidden', (
      tester,
    ) async {
      _appSetting = autoOn.copyWith(unboundedHidden: true);
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      service.manualPort = 5698;
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?', 'manual_port', 'unbounded:false']);
      expect(notifier.state.active, isFalse);
    });

    testWidgets('keeps a resumed session that helps a friend', (tester) async {
      _appSetting = autoOff;
      _helps = true;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?', 'manual_port']);
      expect(helpers(ref).helpsAsked, 1);
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('keeps a resumed session when the helper view cannot be read', (
      tester,
    ) async {
      _appSetting = autoOff;
      _helps = null;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      await launch(notifier, ref);
      expect(service.calls, isNot(contains('unbounded:false')));
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('switches a resumed Unbounded session to SmC for a manual '
        'port', (tester) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.manualPort = 5698;
      service.unboundedOk = true;
      await launch(notifier, ref);
      expect(service.calls, [
        'unbounded?',
        'manual_port',
        'unbounded:false',
        'peer:true',
      ]);
      expect(helpers(ref).helpsAsked, 0, reason: 'wanted, so never asked');
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.smc);
    });

    testWidgets('a switch whose SmC start fails falls back to Unbounded', (
      tester,
    ) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.manualPort = 5698;
      service.peerOk = false;
      service.unboundedOk = true;
      await launch(notifier, ref);
      await tester.pump();
      expect(service.calls, [
        'unbounded?',
        'manual_port',
        'unbounded:false',
        'peer:true',
        'unbounded:true',
      ]);
      expect(notifier.state.mode, ShareMode.unbounded);
      expect(notifier.state.fallbackReason, 'no upnp');
    });

    testWidgets('a volunteer\'s kept session also switches to SmC', (
      tester,
    ) async {
      _appSetting = autoOff;
      _helps = true;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.manualPort = 5698;
      service.unboundedOk = true;
      await launch(notifier, ref);
      expect(service.calls.last, 'peer:true');
      expect(notifier.state.mode, ShareMode.smc);
    });

    testWidgets('keeps a resumed Unbounded session without a manual port', (
      tester,
    ) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?', 'manual_port']);
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('keeps a resumed Unbounded session on iOS', (tester) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      notifier.isIOS = () => true;
      service.unboundedEnabled = true;
      service.manualPort = 5698;
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?']);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('stops a resumed SmC session when auto-enable is off', (
      tester,
    ) async {
      _appSetting = autoOff;
      final (notifier, ref, service) = await _start(tester);
      service.peerStatus = '{"phase":"serving"}';
      await launch(notifier, ref);
      expect(service.calls, ['peer:false']);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.mode, ShareMode.off);
    });

    testWidgets('keeps a resumed SmC session when auto-enable is on', (
      tester,
    ) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      service.peerStatus = '{"phase":"serving"}';
      service.manualPort = 5698;
      await launch(notifier, ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.mode, ShareMode.smc);
    });

    testWidgets('auto-starts Unbounded when nothing was resumed', (
      tester,
    ) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedOk = true;
      service.manualPort = 5698;
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?', 'unbounded:true']);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('does nothing when nothing was resumed and auto-enable is '
        'off', (tester) async {
      _appSetting = autoOff;
      final (notifier, ref, service) = await _start(tester);
      await launch(notifier, ref);
      expect(service.calls, ['unbounded?']);
      expect(helpers(ref).helpsAsked, 0);
      expect(notifier.state.active, isFalse);
    });

    testWidgets('a toggle while the helper view is pending is not ignored, '
        'and the reconciliation leaves the choice alone', (tester) async {
      _appSetting = autoOff;
      _helpsGate = Completer<void>();
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      expect(helpers(ref).helpsAsked, 1);
      expect(notifier.state.active, isTrue, reason: 'shown as resumed');
      // The user turns it off, then on again, while the view is pending.
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isFalse);
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isTrue);
      service.calls.clear();
      _helpsGate!.complete();
      await reconcile;
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('a stop while the helper view is pending is final', (
      tester,
    ) async {
      _appSetting = autoOff;
      _helps = true;
      _helpsGate = Completer<void>();
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      service.manualPort = 5698;
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isFalse);
      service.calls.clear();
      _helpsGate!.complete();
      await reconcile;
      expect(service.calls, isEmpty, reason: 'no switch to SmC either');
      expect(notifier.state.active, isFalse);
    });

    /// SmC resumed with auto-enable off, a non-volunteer's view pending;
    /// then SmC fails and falls back to Unbounded.
    Future<(ShareNotifier, WidgetRef, _FakeService, Future<void>)>
    smcFailsWhileHelpersPending(WidgetTester tester) async {
      _appSetting = autoOff;
      _helpsGate = Completer<void>();
      final (notifier, ref, service) = await _start(tester);
      service.peerStatus = '{"phase":"serving"}';
      service.unboundedOk = true;
      await notifier.syncFromBackend(ref);
      expect(notifier.state.mode, ShareMode.smc);
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      expect(helpers(ref).helpsAsked, 1);
      service.events.add(
        AppEvent(eventType: 'peer-status', message: '{"phase":"error"}'),
      );
      await tester.pump();
      return (notifier, ref, service, reconcile);
    }

    testWidgets('a fallback while the helper view is pending is stopped once '
        'it completes', (tester) async {
      final (notifier, ref, service, reconcile) =
          await smcFailsWhileHelpersPending(tester);
      expect(notifier.state.mode, ShareMode.unbounded);
      _helpsGate!.complete();
      await reconcile;
      expect(service.calls, ['unbounded:true', 'unbounded:false']);
      expect(notifier.state.active, isFalse);
      expect(notifier.state.mode, ShareMode.off);
    });

    testWidgets('a fallback still running when the view arrives is waited for '
        'and stopped', (tester) async {
      _appSetting = autoOff;
      _helpsGate = Completer<void>();
      final (notifier, ref, service) = await _start(tester);
      service.peerStatus = '{"phase":"serving"}';
      service.unboundedOk = true;
      service.unboundedGate = Completer<void>();
      await notifier.syncFromBackend(ref);
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      service.events.add(
        AppEvent(eventType: 'peer-status', message: '{"phase":"error"}'),
      );
      await tester.pump();
      expect(service.calls, ['unbounded:true']);
      _helpsGate!.complete();
      await tester.pump();
      expect(service.calls, ['unbounded:true'], reason: 'waits for it');
      service.unboundedGate!.complete();
      await reconcile;
      expect(service.calls, ['unbounded:true', 'unbounded:false']);
      expect(notifier.state.active, isFalse);
    });

    testWidgets('a toggle after a fallback while the view is pending still '
        'wins', (tester) async {
      final (notifier, ref, service, reconcile) =
          await smcFailsWhileHelpersPending(tester);
      // The user turns the fallback off, then sharing on again.
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isFalse);
      await notifier.toggle(_context!, ref);
      expect(notifier.state.active, isTrue);
      service.calls.clear();
      _helpsGate!.complete();
      await reconcile;
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isTrue);
    });

    testWidgets('a wanted fallback is kept, not switched back to SmC', (
      tester,
    ) async {
      _appSetting = autoOff;
      _helps = true;
      final (notifier, ref, service, reconcile) =
          await smcFailsWhileHelpersPending(tester);
      service.manualPort = 5698;
      _helpsGate!.complete();
      await reconcile;
      expect(service.calls, ['unbounded:true']);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('a pairing approved while a fallback runs keeps the session, '
        'though the view said nobody', (tester) async {
      _appSetting = autoOff;
      _helpsGate = Completer<void>();
      final (notifier, ref, service) = await _start(tester);
      service.peerStatus = '{"phase":"serving"}';
      service.unboundedOk = true;
      service.unboundedGate = Completer<void>();
      await notifier.syncFromBackend(ref);
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      service.events.add(
        AppEvent(eventType: 'peer-status', message: '{"phase":"error"}'),
      );
      await tester.pump();
      _helpsGate!.complete();
      await tester.pump();
      expect(helpers(ref).helpsSomeoneNow, isFalse);
      helpers(ref).helpSomeone();
      service.unboundedGate!.complete();
      await reconcile;
      expect(service.calls, ['unbounded:true']);
      expect(notifier.state.active, isTrue);
      expect(notifier.state.mode, ShareMode.unbounded);
    });

    testWidgets('a pairing approved during the helper wait keeps the session', (
      tester,
    ) async {
      _appSetting = autoOff;
      _helpsGate = Completer<void>();
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      helpers(ref).helpSomeone();
      // The view the reconciliation asked for answers late, and is dropped.
      _helpsGate!.complete();
      await reconcile;
      expect(service.calls, ['unbounded?', 'manual_port']);
      expect(notifier.state.active, isTrue);
    });

    testWidgets('settings changed during the wait decide', (tester) async {
      _appSetting = autoOn;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      service.manualPort = 5698;
      // Auto-enable turned off while the manual port was read.
      service.onManualPort = () =>
          (ref.read(appSettingProvider.notifier) as _Settings).set(autoOff);
      await notifier.reconcileLaunch(ref);
      expect(service.calls, ['unbounded?', 'manual_port', 'unbounded:false']);
      expect(notifier.state.active, isFalse);
    });

    testWidgets('a helper start skipped during the stop runs once it is done', (
      tester,
    ) async {
      addTearDown(() => CountryCode.update(''));
      CountryCode.update('DE');
      _appSetting = autoOff;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedEnabled = true;
      service.unboundedOk = true;
      service.unboundedGate = Completer<void>();
      final reconcile = notifier.reconcileLaunch(ref);
      await tester.pump();
      expect(service.calls.last, 'unbounded:false');
      // Approved while the stop runs: the start is held back, not lost.
      helpers(ref).helpSomeone();
      await notifier.startForHelper(ref);
      service.unboundedGate!.complete();
      await reconcile;
      expect(service.calls, [
        'unbounded?',
        'manual_port',
        'unbounded:false',
        'manual_port',
        'upnp',
        'unbounded:true',
      ]);
      expect(notifier.state.active, isTrue);
    });

    testWidgets('runs once, and never on a session this run started', (
      tester,
    ) async {
      _appSetting = autoOff;
      final (notifier, ref, service) = await _start(tester);
      service.unboundedOk = true;
      await notifier.autoStart(ref);
      service.calls.clear();
      service.unboundedEnabled = true;
      await notifier.reconcileLaunch(ref);
      expect(service.calls, isEmpty);
      expect(notifier.state.active, isTrue);
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
