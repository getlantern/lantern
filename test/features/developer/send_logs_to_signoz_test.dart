import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/developer/notifier/developer_daemon_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// Radiance applies a settings patch live before it saves it, so a patch
/// whose save fails can still have changed the value.
class _Service implements LanternService {
  _Service(this.live);

  Map<String, dynamic> live;
  bool failSave = false;
  Completer<void>? holdReads;
  Completer<void>? holdFirstPatch;
  final patches = <Map<String, dynamic>>[];

  @override
  Future<Either<Failure, Unit>> patchSettings(
    Map<String, dynamic> updates,
  ) async {
    final hold = holdFirstPatch;
    holdFirstPatch = null;
    await hold?.future;
    patches.add(updates);
    live = {...live, ...updates};
    if (failSave) {
      return left(Failure(error: 'save failed', localizedErrorMessage: ''));
    }
    return right(unit);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async {
    final snapshot = live;
    await holdReads?.future;
    return right(snapshot);
  }

  @override
  Future<Either<Failure, Map<String, String>>> getEnvVars() async => right({});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _load(_Service service) async {
  final container = ProviderContainer(
    overrides: [lanternServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  container.listen(developerDaemonProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
  expect(container.read(developerDaemonProvider).loading, isFalse);
  return container;
}

void main() {
  test(
    'reads the upload switch and telemetry from radiance settings',
    () async {
      final container = await _load(
        _Service({
          kSettingSendLogsToSigNoz: true,
          kSettingTelemetryEnabled: true,
        }),
      );
      final state = container.read(developerDaemonProvider);
      expect(state.sendLogsToSigNoz, isTrue);
      expect(state.telemetryEnabled, isTrue);
    },
  );

  test('unset settings read as off', () async {
    final container = await _load(_Service({}));
    final state = container.read(developerDaemonProvider);
    expect(state.sendLogsToSigNoz, isFalse);
    expect(state.telemetryEnabled, isFalse);
  });

  test('the switch patches send_logs_to_signoz', () async {
    final service = _Service({});
    final container = await _load(service);

    final result = await container
        .read(developerDaemonProvider.notifier)
        .setSendLogsToSigNoz(true);
    expect(result.isRight(), isTrue);
    expect(service.patches, [
      {'send_logs_to_signoz': true},
    ]);
    expect(container.read(developerDaemonProvider).sendLogsToSigNoz, isTrue);
  });

  test('a failed save shows the value radiance actually applied', () async {
    final service = _Service({})..failSave = true;
    final container = await _load(service);

    final result = await container
        .read(developerDaemonProvider.notifier)
        .setSendLogsToSigNoz(true);
    expect(
      result.isLeft(),
      isTrue,
      reason: 'the error still reaches the caller',
    );
    expect(
      container.read(developerDaemonProvider).sendLogsToSigNoz,
      isTrue,
      reason: 'the switch shows upload on, as radiance has it',
    );
  });

  test(
    'a later change waits for an earlier failed save to read back',
    () async {
      final service = _Service({})..failSave = true;
      final container = await _load(service);
      final notifier = container.read(developerDaemonProvider.notifier);

      service.holdReads = Completer<void>();
      final first = notifier.setSendLogsToSigNoz(false);
      await Future<void>.delayed(Duration.zero);
      expect(service.patches, hasLength(1), reason: 'the first save failed');
      service.failSave = false;
      final second = notifier.setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      expect(
        service.patches,
        hasLength(1),
        reason: 'the second write waits for the first read-back',
      );
      service.holdReads!.complete();
      expect((await first).isLeft(), isTrue);
      expect((await second).isRight(), isTrue);

      expect(
        container.read(developerDaemonProvider).sendLogsToSigNoz,
        isTrue,
        reason: 'the later change wins over the stale read-back',
      );
    },
  );

  test('writes apply in the order they were made', () async {
    final service = _Service({});
    final container = await _load(service);
    final notifier = container.read(developerDaemonProvider.notifier);

    final hold = service.holdFirstPatch = Completer<void>();
    final enable = notifier.setSendLogsToSigNoz(true);
    final disable = notifier.setSendLogsToSigNoz(false);
    await Future<void>.delayed(Duration.zero);
    hold.complete();
    await enable;
    await disable;

    expect(service.patches, [
      {'send_logs_to_signoz': true},
      {'send_logs_to_signoz': false},
    ]);
    expect(service.live['send_logs_to_signoz'], isFalse);
    expect(container.read(developerDaemonProvider).sendLogsToSigNoz, isFalse);
  });

  test(
    'a queued write still reaches radiance after the screen closes',
    () async {
      final service = _Service({});
      final container = await _load(service);
      final notifier = container.read(developerDaemonProvider.notifier);

      final hold = service.holdFirstPatch = Completer<void>();
      final enable = notifier.setSendLogsToSigNoz(true);
      final disable = notifier.setSendLogsToSigNoz(false);
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      hold.complete();
      await enable;
      expect((await disable).isRight(), isTrue);

      expect(service.patches, [
        {'send_logs_to_signoz': true},
        {'send_logs_to_signoz': false},
      ]);
    },
  );

  test(
    'writes from a reopened screen queue behind ones from before it closed',
    () async {
      final service = _Service({});
      final first = await _load(service);
      final oldScreen = first.read(developerDaemonProvider.notifier);

      final hold = service.holdFirstPatch = Completer<void>();
      final a = oldScreen.setSendLogsToSigNoz(false);
      final b = oldScreen.setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final second = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(second.dispose);
      second.listen(developerDaemonProvider, (_, _) {});
      final c = second
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(false);
      hold.complete();
      await a;
      await b;
      await c;

      expect(service.patches, [
        {'send_logs_to_signoz': false},
        {'send_logs_to_signoz': true},
        {'send_logs_to_signoz': false},
      ]);
      expect(service.live['send_logs_to_signoz'], isFalse);
      expect(second.read(developerDaemonProvider).sendLogsToSigNoz, isFalse);
    },
  );

  test(
    'a reopened screen shows a write that was still running when it closed',
    () async {
      final service = _Service({});
      final first = await _load(service);

      final hold = service.holdFirstPatch = Completer<void>();
      final enable = first
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final second = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(second.dispose);
      second.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(
        second.read(developerDaemonProvider).loading,
        isFalse,
        reason: 'the rest of the screen does not wait for the write',
      );
      expect(
        second.read(developerDaemonProvider).sendLogsToSigNoz,
        isFalse,
        reason: 'the switch reads only after the running write',
      );

      hold.complete();
      await enable;
      await Future<void>.delayed(Duration.zero);
      expect(second.read(developerDaemonProvider).sendLogsToSigNoz, isTrue);
    },
  );
}
