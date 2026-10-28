import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/helpers/helper_key_store.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final calls = <String>[];
  final patches = <Map<String, dynamic>>[];
  int configRequests = 0;
  Map<String, String> answers = {};
  Either<Failure, String>? raw;

  /// Answers used once each, before [answers].
  final queued = <String, List<String>>{};

  /// An op waits for its gate before it answers.
  final gates = <String, Future<void>>{};
  String flags = '{}';
  bool configThrows = false;

  @override
  Future<Either<Failure, String>> helperCall(
    String op,
    Map<String, dynamic> args,
  ) async {
    calls.add(op);
    final q = queued[op];
    final answer = q != null && q.isNotEmpty ? q.removeAt(0) : answers[op];
    final gate = gates.remove(op);
    if (gate != null) await gate;
    return raw ?? right(answer ?? '{"error":"internal"}');
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async =>
      right({'peer_serve_pool': false});

  @override
  Future<Either<Failure, Unit>> patchSettings(
    Map<String, dynamic> updates,
  ) async {
    patches.add(updates);
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> sendConfigRequest() async {
    configRequests++;
    if (configThrows) throw StateError('config');
    return right(unit);
  }

  @override
  Future<Either<Failure, String>> featureFlag() async => right(flags);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Keys implements HelperKeyStore {
  _Keys({this.fail = false});
  final bool fail;
  int reads = 0;
  @override
  Future<String> stateKey() async {
    reads++;
    if (fail) throw StateError('no keyring');
    return base64.encode(List.filled(32, 1));
  }
}

class _Storage implements LocalStorageService {
  final values = <String, bool>{};
  @override
  bool? getBool(String key) => values[key];
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _view({
  bool newHelping = false,
  bool helpersChanged = false,
  String helpers = '[]',
  String invites = '[]',
}) =>
    '{"unlocked":true,"my_name":"","invites":$invites,"claims":[],"helpers":$helpers,'
    '"helping":[],"new_helping":$newHelping'
    '${helpersChanged ? ',"helpers_changed":true' : ''}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Service svc;
  late _Storage storage;
  late _Keys keys;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(svc)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    svc = _Service();
    storage = _Storage();
    sl.registerSingleton<LocalStorageService>(storage);
    keys = _Keys();
    sl.registerSingleton<HelperKeyStore>(keys);
    HelpersNotifier.debugBuildEnabled = null;
  });
  tearDown(() {
    HelpersNotifier.debugBuildEnabled = null;
    HelpersNotifier.pollInterval = const Duration(seconds: 30);
    return sl.reset();
  });

  test('refresh unlocks once and applies the view', () async {
    svc.answers = {
      'unlock': _view(),
      'refresh': _view(
        helpers:
            '[{"pairing_id":"p1","name":"Ali","online":true,"since_unix":1}]',
      ),
    };
    final c = container();
    final r = await c.read(helpersProvider.notifier).refresh();
    expect(r.ok, isTrue);
    expect(svc.calls, ['unlock', 'refresh']);
    expect(c.read(helpersProvider).view.helpers.single.name, 'Ali');
    expect(storage.values[HelpersNotifier.usedKey], isTrue);
    await c.read(helpersProvider.notifier).refresh();
    expect(svc.calls, [
      'unlock',
      'refresh',
      'refresh',
    ], reason: 'unlock runs once');
  });

  test(
    'refreshIfUsed touches nothing for a device that never used helpers',
    () async {
      final c = container();
      await c.read(helpersProvider.notifier).refreshIfUsed();
      expect(svc.calls, isEmpty);
      expect(storage.values.containsKey(HelpersNotifier.usedKey), isFalse);
      expect(keys.reads, 0);
    },
  );

  test('an error envelope becomes the state error', () async {
    svc.answers = {
      'unlock': _view(),
      'create_invite': '{"error":"too_many_invites"}',
    };
    final c = container();
    final r = await c.read(helpersProvider.notifier).createInvite('Sara');
    expect(r.error, 'too_many_invites');
    expect(c.read(helpersProvider).error, 'too_many_invites');
  });

  test(
    'a new pairing to help counts an approval and refetches config',
    () async {
      svc.answers = {'unlock': _view(), 'refresh': _view(newHelping: true)};
      final c = container();
      await c.read(helpersProvider.notifier).refresh();
      expect(c.read(helpersProvider).helpingApprovals, 1);
      await Future<void>.delayed(Duration.zero);
      expect(svc.configRequests, 1);
    },
  );

  group('a change to who helps this device refetches config once', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('approving a helper', () async {
      svc.answers = {'decide': _view()};
      final c = container();
      final r = await c
          .read(helpersProvider.notifier)
          .decide('i1', approve: true);
      expect(r.ok, isTrue);
      await settle();
      expect(svc.configRequests, 1);
    });

    test('rejecting a claim does not', () async {
      svc.answers = {'decide': _view()};
      final c = container();
      await c.read(helpersProvider.notifier).decide('i1', approve: false);
      await settle();
      expect(svc.configRequests, 0);
    });

    test('a failed approve does not', () async {
      svc.answers = {'decide': '{"error":"no_pending_claim"}'};
      final c = container();
      final r = await c
          .read(helpersProvider.notifier)
          .decide('i1', approve: true);
      expect(r.ok, isFalse);
      await settle();
      expect(svc.configRequests, 0);
    });

    test('ending a pairing', () async {
      svc.answers = {'end_pairing': _view()};
      final c = container();
      await c.read(helpersProvider.notifier).endPairing('p1');
      await settle();
      expect(svc.configRequests, 1);
    });

    test('a failed end does not', () async {
      svc.answers = {'end_pairing': '{"error":"unavailable"}'};
      final c = container();
      await c.read(helpersProvider.notifier).endPairing('p1');
      await settle();
      expect(svc.configRequests, 0);
    });

    test('removing all helpers', () async {
      svc.answers = {'end_all_helpers': _view()};
      final c = container();
      await c.read(helpersProvider.notifier).endAllHelpers();
      await settle();
      expect(svc.configRequests, 1);
    });

    test('a refresh whose view says helpers_changed', () async {
      svc.answers = {'unlock': _view(), 'refresh': _view(helpersChanged: true)};
      final c = container();
      final n = c.read(helpersProvider.notifier);
      await n.refresh();
      await settle();
      expect(svc.configRequests, 1);
      expect(
        c.read(helpersProvider).helpingApprovals,
        0,
        reason: 'not a new person to help',
      );
      svc.answers['refresh'] = _view();
      await n.refresh();
      await settle();
      expect(svc.configRequests, 1, reason: 'only the view that says so');
    });

    test('a view with both flags refetches once', () async {
      svc.answers = {
        'unlock': _view(),
        'refresh': _view(newHelping: true, helpersChanged: true),
      };
      final c = container();
      await c.read(helpersProvider.notifier).refresh();
      await settle();
      expect(svc.configRequests, 1);
    });
  });

  test('a keystore failure never calls the engine', () async {
    sl.unregister<HelperKeyStore>();
    sl.registerSingleton<HelperKeyStore>(_Keys(fail: true));
    final c = container();
    final r = await c.read(helpersProvider.notifier).refresh();
    expect(r.error, 'keystore');
    expect(svc.calls, isEmpty);
  });

  test('help others too reads and writes peer_serve_pool', () async {
    final c = container();
    await c.read(helpersProvider.notifier).loadHelpOthers();
    expect(c.read(helpersProvider).helpOthers, isFalse);
    await c.read(helpersProvider.notifier).setHelpOthers(true);
    expect(svc.patches.single, {'peer_serve_pool': true});
    expect(c.read(helpersProvider).helpOthers, isTrue);
  });

  group('a core that is not ready answers unavailable', () {
    final cases = <String, Either<Failure, String>>{
      'desktop before the core is up': right('{"error":"not_initialized"}'),
      'mobile platform exception': left(
        Failure(
          error: 'PlatformException(HELPER_CALL_FAILED)',
          localizedErrorMessage: '',
        ),
      ),
      'a null platform reply': right(''),
      'not JSON': right('<html>'),
      'a JSON array': right('[]'),
    };
    cases.forEach((name, answer) {
      test(name, () async {
        svc.raw = answer;
        final c = container();
        final r = await c.read(helpersProvider.notifier).refresh();
        expect(r.ok, isFalse);
        expect(r.error, 'unavailable');
        expect(c.read(helpersProvider).error, 'unavailable');
        expect(svc.calls, ['unlock'], reason: 'a failed unlock stops there');
      });
    });
  });

  test('a keystore reset stays until the user acknowledges it', () async {
    svc.answers = {
      'unlock':
          '{"unlocked":true,"invites":[],"claims":[],"helpers":[],"helping":[],"keystore_reset":true}',
      'refresh': _view(),
    };
    final c = container();
    final n = c.read(helpersProvider.notifier);
    await n.refresh();
    expect(svc.calls, ['unlock', 'refresh']);
    expect(c.read(helpersProvider).keystoreReset, isTrue);
    expect(c.read(helpersProvider).error, isNull);
    await n.refresh();
    expect(c.read(helpersProvider).keystoreReset, isTrue);
    n.acknowledgeKeystoreReset();
    expect(c.read(helpersProvider).keystoreReset, isFalse);
  });

  group('a relocked engine', () {
    test('unlocks again and retries the op once', () async {
      svc.answers = {'unlock': _view(), 'refresh': _view()};
      final c = container();
      final n = c.read(helpersProvider.notifier);
      await n.refresh();
      svc.queued['refresh'] = ['{"error":"locked"}'];
      final r = await n.refresh();
      expect(r.ok, isTrue);
      expect(svc.calls, ['unlock', 'refresh', 'refresh', 'unlock', 'refresh']);
      expect(keys.reads, 2);
    });

    test('recovers an op that has no unlock guard', () async {
      svc.answers = {
        'unlock': _view(),
        'refresh': _view(),
        'end_pairing': _view(),
      };
      final c = container();
      final n = c.read(helpersProvider.notifier);
      await n.refresh();
      svc.queued['end_pairing'] = ['{"error":"locked"}'];
      final r = await n.endPairing('p1');
      expect(r.ok, isTrue);
      expect(svc.calls.sublist(2), ['end_pairing', 'unlock', 'end_pairing']);
    });

    test('a second locked answer is final', () async {
      svc.answers = {'unlock': _view(), 'refresh': _view()};
      final c = container();
      final n = c.read(helpersProvider.notifier);
      await n.refresh();
      svc.queued['refresh'] = ['{"error":"locked"}', '{"error":"locked"}'];
      final r = await n.refresh();
      expect(r.error, 'unavailable');
      expect(svc.calls.sublist(2), ['refresh', 'unlock', 'refresh']);
    });

    test('concurrent locked answers share one unlock', () async {
      svc.answers = {'unlock': _view(), 'refresh': _view(), 'view': _view()};
      final c = container();
      final n = c.read(helpersProvider.notifier);
      await n.refresh();
      svc.queued['refresh'] = ['{"error":"locked"}'];
      svc.queued['view'] = ['{"error":"locked"}'];
      final rs = await Future.wait([n.refresh(), n.refreshView()]);
      expect(rs.every((r) => r.ok), isTrue);
      expect(svc.calls.where((op) => op == 'unlock'), hasLength(2));
      expect(keys.reads, 2);
    });

    test('a device that never used helpers does not unlock', () async {
      svc.answers = {'view': '{"error":"locked"}'};
      final c = container();
      final r = await c.read(helpersProvider.notifier).refreshView();
      expect(r.error, 'locked');
      expect(svc.calls, ['view']);
      expect(keys.reads, 0);
    });
  });

  test('two concurrent refreshes unlock once', () async {
    svc.answers = {'unlock': _view(), 'refresh': _view()};
    final c = container();
    final n = c.read(helpersProvider.notifier);
    await Future.wait([n.refresh(), n.refresh()]);
    expect(svc.calls.where((op) => op == 'unlock'), hasLength(1));
    expect(keys.reads, 1);
  });

  test('a stealth build never touches the keystore or the engine', () async {
    HelpersNotifier.debugBuildEnabled = false;
    svc.answers = {'unlock': _view(), 'refresh': _view(), 'claim': '{}'};
    final c = container();
    final n = c.read(helpersProvider.notifier);
    expect(await n.ensureUnlocked(), isFalse);
    expect((await n.refresh()).error, 'unavailable');
    expect((await n.claim('link', 'Ali')).error, 'unavailable');
    expect((await n.createInvite('Sara')).error, 'unavailable');
    expect((await n.decide('i1', approve: true)).error, 'unavailable');
    await n.refreshIfUsed();
    expect(svc.calls, isEmpty);
    expect(keys.reads, 0);
    expect(storage.values.containsKey(HelpersNotifier.usedKey), isFalse);
  });

  test('an older view never overwrites a newer one', () async {
    svc.answers = {'unlock': _view()};
    final c = container();
    final n = c.read(helpersProvider.notifier);
    await n.ensureUnlocked();
    final gate = Completer<void>();
    svc.gates['refresh'] = gate.future;
    svc.answers['refresh'] = _view(helpers: '[{"pairing_id":"old"}]');
    final slow = n.refresh();
    await Future<void>.delayed(Duration.zero);
    svc.answers['view'] = _view(helpers: '[{"pairing_id":"new"}]');
    await n.refreshView();
    gate.complete();
    await slow;
    expect(c.read(helpersProvider).view.helpers.single.pairingId, 'new');
  });

  test('a failing config refetch is contained', () async {
    svc.answers = {'unlock': _view(), 'refresh': _view(newHelping: true)};
    svc.configThrows = true;
    final c = container();
    await c.read(helpersProvider.notifier).refresh();
    await Future<void>.delayed(Duration.zero);
    expect(svc.configRequests, 1);
  });

  group('helperInvitesAvailableProvider', () {
    // The provider reads the build const, which is on in tests; the stealth
    // side is covered by the notifier's guard test above.
    for (final flag in [true, false]) {
      test('follows the helper_invites flag ($flag)', () async {
        svc.flags = '{"helper_invites":$flag}';
        final c = container();
        await c.read(featureFlagProvider.notifier).fetchFeatureFlags();
        expect(c.read(helperInvitesAvailableProvider), flag);
      });
    }
  });

  test('polling starts and stops with needsPolling', () async {
    HelpersNotifier.pollInterval = const Duration(milliseconds: 10);
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    svc.answers = {
      'unlock': _view(),
      'refresh': _view(invites: '[{"id":"i1","state":"pending"}]'),
    };
    final c = container();
    final n = c.read(helpersProvider.notifier);
    await n.refresh();
    expect(n.polling, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(svc.calls.where((op) => op == 'refresh').length, greaterThan(1));
    svc.answers['refresh'] = _view();
    await n.refresh();
    expect(n.polling, isFalse);
    final after = svc.calls.length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(svc.calls.length, after);
  });
}
