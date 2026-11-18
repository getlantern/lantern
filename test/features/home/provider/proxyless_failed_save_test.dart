import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// Radiance applies a settings patch live before it saves it, so a patch
/// whose save fails can still have changed the value.
class _Service implements LanternService {
  Map<String, dynamic> live = {};
  bool failSave = false;

  @override
  Future<Either<Failure, Unit>> patchSettings(
    Map<String, dynamic> updates,
  ) async {
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
  Future<Either<Failure, bool>> isBlockAdsEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isSmartRoutingEnabled() async => right(true);
  @override
  Future<Either<Failure, bool>> isTelemetryEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isPeerProxyEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isUnboundedEnabled() async => right(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a failed save shows the value radiance actually applied', () async {
    final service = _Service();
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(radianceSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(radianceSettingsProvider).proxyless, isTrue);

    service.failSave = true;
    final result = await container
        .read(radianceSettingsProvider.notifier)
        .setProxyless(false);
    expect(
      result.isLeft(),
      isTrue,
      reason: 'the error still reaches the caller',
    );
    expect(
      container.read(radianceSettingsProvider).proxyless,
      isFalse,
      reason: 'the switch shows proxyless off, as radiance has it',
    );
  });
}
