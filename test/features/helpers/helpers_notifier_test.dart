import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/helpers/helper_key_store.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final calls = <String>[];
  final patches = <Map<String, dynamic>>[];
  int configRequests = 0;
  Map<String, String> answers = {};
  Either<Failure, String>? raw;

  @override
  Future<Either<Failure, String>> helperCall(
    String op,
    Map<String, dynamic> args,
  ) async {
    calls.add(op);
    return raw ?? right(answers[op] ?? '{"error":"internal"}');
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
    return right(unit);
  }

  @override
  Future<Either<Failure, String>> featureFlag() async => right('{}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Keys implements HelperKeyStore {
  _Keys({this.fail = false});
  final bool fail;
  @override
  Future<String> stateKey() async {
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
  String helpers = '[]',
  String invites = '[]',
}) =>
    '{"unlocked":true,"my_name":"","invites":$invites,"claims":[],"helpers":$helpers,'
    '"helping":[],"new_helping":$newHelping}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Service svc;
  late _Storage storage;

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
    sl.registerSingleton<HelperKeyStore>(_Keys());
  });
  tearDown(() => sl.reset());

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

  test('a keystore reset on unlock is reported once', () async {
    svc.answers = {
      'unlock':
          '{"unlocked":true,"invites":[],"claims":[],"helpers":[],"helping":[],"keystore_reset":true}',
      'refresh': _view(),
    };
    final c = container();
    await c.read(helpersProvider.notifier).ensureUnlocked();
    expect(c.read(helpersProvider).error, 'keystore_reset');
    await c.read(helpersProvider.notifier).refresh();
    expect(c.read(helpersProvider).error, isNull);
  });
}
