import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/developer/notifier/developer_daemon_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
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

  /// Writes in the order they reached radiance.
  final calls = <String>[];
  Completer<void>? holdTelemetryWrite;

  @override
  Future<Either<Failure, Unit>> patchSettings(
    Map<String, dynamic> updates,
  ) async {
    final hold = holdFirstPatch;
    holdFirstPatch = null;
    await hold?.future;
    patches.add(updates);
    calls.add('patch');
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

  Completer<void>? holdEnv;

  @override
  Future<Either<Failure, Map<String, String>>> getEnvVars() async {
    await holdEnv?.future;
    return right({});
  }

  Completer<void>? holdTelemetryReads;

  /// Holds for successive consent reads, used in order.
  final telemetryReadHolds = <Completer<void>>[];

  /// Consent reads still to fail, counted down as reads start.
  int failTelemetryReads = 0;
  bool failTelemetryWrite = false;

  @override
  Future<Either<Failure, bool>> isTelemetryEnabled() async {
    if (failTelemetryReads > 0) {
      failTelemetryReads--;
      return left(Failure(error: 'read failed', localizedErrorMessage: ''));
    }
    final snapshot = live[kSettingTelemetryEnabled] == true;
    final hold = telemetryReadHolds.isEmpty
        ? holdTelemetryReads
        : telemetryReadHolds.removeAt(0);
    await hold?.future;
    return right(snapshot);
  }

  @override
  Future<Either<Failure, Unit>> updateTelemetryEvents(bool consent) async {
    calls.add('consent=$consent');
    final hold = holdTelemetryWrite;
    holdTelemetryWrite = null;
    await hold?.future;
    if (failTelemetryWrite) {
      return left(Failure(error: 'write failed', localizedErrorMessage: ''));
    }
    live = {...live, kSettingTelemetryEnabled: consent};
    return right(unit);
  }

  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() async => right(false);

  @override
  Future<Either<Failure, bool>> isSmartRoutingEnabled() async => right(false);

  @override
  Future<Either<Failure, bool>> isPeerProxyEnabled() async => right(false);

  @override
  Future<Either<Failure, bool>> isUnboundedEnabled() async => right(false);

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
    expect(state.sendLogsToSigNozLoaded, isTrue);
    },
  );

  test('unset settings read as off', () async {
    final container = await _load(_Service({}));
    final state = container.read(developerDaemonProvider);
    expect(state.sendLogsToSigNoz, isFalse);
    expect(state.telemetryEnabled, isFalse);
  });

  test(
    'turning upload on turns telemetry consent on in the same patch',
    () async {
      final service = _Service({});
      final container = await _load(service);

      final result = await container
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      expect(result.isRight(), isTrue);
      expect(service.patches, [
        {'send_logs_to_signoz': true, 'telemetry_enabled': true},
      ]);
      final state = container.read(developerDaemonProvider);
      expect(state.sendLogsToSigNoz, isTrue);
      expect(state.telemetryEnabled, isTrue);
    },
  );

  test(
    'the settings screen shows consent on, even if the screen closed first',
    () async {
      final service = _Service({});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(radianceSettingsProvider, (_, _) {});
      final screen = container.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(radianceSettingsProvider).telemetry, isFalse);

      final hold = service.holdFirstPatch = Completer<void>();
      final enable = container
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      screen.close();
      await Future<void>.delayed(Duration.zero);
      hold.complete();
      expect((await enable).isRight(), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(radianceSettingsProvider).telemetry, isTrue);
    },
  );

  test(
    'a consent read older than a later consent change is dropped',
    () async {
      final service = _Service({});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(radianceSettingsProvider, (_, _) {});
      container.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final hold = service.holdTelemetryReads = Completer<void>();
      await container
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      await container.read(radianceSettingsProvider.notifier).setTelemetry(false);
      hold.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(radianceSettingsProvider).telemetry, isFalse);
    },
  );

  test(
    'a queued enable does not undo a later opt-out in Settings',
    () async {
      final service = _Service({});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(radianceSettingsProvider, (_, _) {});
      container.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final notifier = container.read(developerDaemonProvider.notifier);

      final hold = service.holdFirstPatch = Completer<void>();
      final earlier = notifier.setSendLogsToSigNoz(false);
      final enable = notifier.setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      await container.read(radianceSettingsProvider.notifier).setTelemetry(false);
      hold.complete();
      await earlier;
      expect((await enable).isRight(), isTrue);

      expect(service.patches, [
        {'send_logs_to_signoz': false},
        {'send_logs_to_signoz': true},
      ]);
      expect(service.live[kSettingTelemetryEnabled], isFalse);
      expect(container.read(developerDaemonProvider).telemetryEnabled, isFalse);
    },
  );

  test('an opt-out sent while an enable is in flight lands last', () async {
    final service = _Service({});
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(radianceSettingsProvider, (_, _) {});
    container.listen(developerDaemonProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final hold = service.holdFirstPatch = Completer<void>();
    final enable = container
        .read(developerDaemonProvider.notifier)
        .setSendLogsToSigNoz(true);
    await Future<void>.delayed(Duration.zero);
    final optOut =
        container.read(radianceSettingsProvider.notifier).setTelemetry(false);
    await Future<void>.delayed(Duration.zero);
    expect(service.calls, isEmpty, reason: 'the opt-out waits for the enable');
    hold.complete();
    await enable;
    await optOut;

    expect(service.calls, ['patch', 'consent=false']);
    expect(service.live[kSettingTelemetryEnabled], isFalse);
  });

  test(
    'a skipped grant shows consent as the newer choice left it',
    () async {
      final service = _Service({kSettingTelemetryEnabled: true});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(radianceSettingsProvider, (_, _) {});
      container.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final notifier = container.read(developerDaemonProvider.notifier);
      expect(container.read(developerDaemonProvider).telemetryEnabled, isTrue);

      final hold = service.holdFirstPatch = Completer<void>();
      final earlier = notifier.setSendLogsToSigNoz(false);
      final enable = notifier.setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      await container.read(radianceSettingsProvider.notifier).setTelemetry(false);
      hold.complete();
      await earlier;
      await enable;

      expect(container.read(developerDaemonProvider).telemetryEnabled, isFalse);
    },
  );

  test(
    'a consent read that answers after a consent write is dropped',
    () async {
      final service = _Service({kSettingTelemetryEnabled: true});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(radianceSettingsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final settings = container.read(radianceSettingsProvider.notifier);

      final write = service.holdTelemetryWrite = Completer<void>();
      final optOut = settings.setTelemetry(false);
      await Future<void>.delayed(Duration.zero);
      final read = Completer<void>();
      service.telemetryReadHolds.add(read);
      final refresh = settings.refreshTelemetry();
      await Future<void>.delayed(Duration.zero);
      write.complete();
      await optOut;
      read.complete();
      await refresh;

      expect(container.read(radianceSettingsProvider).telemetry, isFalse);
    },
  );

  test(
    'a reopened screen whose load answers late keeps the consent a pending '
    'write turned on',
    () async {
      final service = _Service({});
      final first = await _load(service);

      final hold = service.holdFirstPatch = Completer<void>();
      final enable = first
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final env = service.holdEnv = Completer<void>();
      final second = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(second.dispose);
      second.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      hold.complete();
      await enable;
      await Future<void>.delayed(Duration.zero);
      expect(second.read(developerDaemonProvider).telemetryEnabled, isTrue);
      env.complete();
      await Future<void>.delayed(Duration.zero);

      expect(second.read(developerDaemonProvider).telemetryEnabled, isTrue);
    },
  );

  test(
    'a consent re-read that fails leaves the settings load to show consent',
    () async {
      final service = _Service({kSettingTelemetryEnabled: true});
      final load = Completer<void>();
      service.telemetryReadHolds.add(load);
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(radianceSettingsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      service.failTelemetryReads = 1;
      await container
          .read(radianceSettingsProvider.notifier)
          .refreshTelemetry();
      load.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(radianceSettingsProvider).telemetry, isTrue);
    },
  );

  test('a consent write that fails shows the consent radiance kept', () async {
    final service = _Service({kSettingTelemetryEnabled: true});
    final load = Completer<void>();
    service.telemetryReadHolds.add(load);
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(radianceSettingsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    service.failTelemetryWrite = true;
    await container.read(radianceSettingsProvider.notifier).setTelemetry(false);
    load.complete();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(radianceSettingsProvider).telemetry, isTrue);
  });

  test('only the latest consent refresh applies', () async {
    final service = _Service({});
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(radianceSettingsProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final settings = container.read(radianceSettingsProvider.notifier);

    final older = Completer<void>();
    service.telemetryReadHolds.addAll([older, Completer<void>()..complete()]);
    final first = settings.refreshTelemetry();
    service.live = {...service.live, kSettingTelemetryEnabled: true};
    await settings.refreshTelemetry();
    expect(container.read(radianceSettingsProvider).telemetry, isTrue);
    older.complete();
    await first;

    expect(container.read(radianceSettingsProvider).telemetry, isTrue);
  });

  test(
    'settings read while an enable is pending show consent on once it lands',
    () async {
      final service = _Service({});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final hold = service.holdFirstPatch = Completer<void>();
      final enable = container
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      container.listen(radianceSettingsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(radianceSettingsProvider).telemetry, isFalse);
      hold.complete();
      expect((await enable).isRight(), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(radianceSettingsProvider).telemetry, isTrue);
    },
  );

  test(
    'an enable that lands after everything was disposed raises nothing',
    () async {
      final service = _Service({});
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );
      container.listen(radianceSettingsProvider, (_, _) {});
      container.listen(developerDaemonProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final hold = service.holdFirstPatch = Completer<void>();
      final enable = container
          .read(developerDaemonProvider.notifier)
          .setSendLogsToSigNoz(true);
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      hold.complete();
      expect((await enable).isRight(), isTrue);
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('turning upload off leaves telemetry consent alone', () async {
    final service = _Service({
      kSettingSendLogsToSigNoz: true,
      kSettingTelemetryEnabled: true,
    });
    final container = await _load(service);

    final result = await container
        .read(developerDaemonProvider.notifier)
        .setSendLogsToSigNoz(false);
    expect(result.isRight(), isTrue);
    expect(service.patches, [
      {'send_logs_to_signoz': false},
    ]);
    final state = container.read(developerDaemonProvider);
    expect(state.sendLogsToSigNoz, isFalse);
    expect(state.telemetryEnabled, isTrue);
  });

  test('a failed save shows the consent radiance actually applied', () async {
    final service = _Service({})..failSave = true;
    final container = await _load(service);

    await container
        .read(developerDaemonProvider.notifier)
        .setSendLogsToSigNoz(true);
    expect(container.read(developerDaemonProvider).telemetryEnabled, isTrue);
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
      {'send_logs_to_signoz': true, 'telemetry_enabled': true},
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
        {'send_logs_to_signoz': true, 'telemetry_enabled': true},
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
        {'send_logs_to_signoz': true, 'telemetry_enabled': true},
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
        second.read(developerDaemonProvider).sendLogsToSigNozLoaded,
        isFalse,
        reason: 'the switch reads only after the running write',
      );

      hold.complete();
      await enable;
      await Future<void>.delayed(Duration.zero);
      expect(second.read(developerDaemonProvider).sendLogsToSigNoz, isTrue);
      expect(
        second.read(developerDaemonProvider).telemetryEnabled,
        isTrue,
        reason: 'the reopened screen reads the consent the write turned on',
      );
      expect(
        second.read(developerDaemonProvider).sendLogsToSigNozLoaded,
        isTrue,
      );
    },
  );
}
