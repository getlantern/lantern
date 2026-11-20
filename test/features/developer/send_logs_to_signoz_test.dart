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
  final patches = <Map<String, dynamic>>[];

  @override
  Future<Either<Failure, Unit>> patchSettings(
    Map<String, dynamic> updates,
  ) async {
    patches.add(updates);
    live = {...live, ...updates};
    if (failSave) {
      return left(Failure(error: 'save failed', localizedErrorMessage: ''));
    }
    return right(unit);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async =>
      right(live);

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
  container.listen(developerDaemonProvider, (_, __) {});
  await Future<void>.delayed(Duration.zero);
  expect(container.read(developerDaemonProvider).loading, isFalse);
  return container;
}

void main() {
  test('reads the upload switch and telemetry from radiance settings',
      () async {
    final container = await _load(_Service({
      kSettingSendLogsToSigNoz: true,
      kSettingTelemetryEnabled: true,
    }));
    final state = container.read(developerDaemonProvider);
    expect(state.sendLogsToSigNoz, isTrue);
    expect(state.telemetryEnabled, isTrue);
  });

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
    expect(result.isLeft(), isTrue, reason: 'the error still reaches the caller');
    expect(
      container.read(developerDaemonProvider).sendLogsToSigNoz,
      isTrue,
      reason: 'the switch shows upload on, as radiance has it',
    );
  });
}
