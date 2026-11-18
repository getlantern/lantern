import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// A service whose settings calls wait on completers the test controls.
class _Service implements LanternService {
  Map<String, dynamic> live = {};
  final patches = <bool>[];
  final patchGates = <Completer<void>>[];
  Completer<void>? readGate;

  @override
  Future<Either<Failure, Unit>> patchSettings(
    Map<String, dynamic> updates,
  ) async {
    patches.add(updates[proxylessSettingKey] as bool);
    final gate = Completer<void>();
    patchGates.add(gate);
    await gate.future;
    live = {...live, ...updates};
    return right(unit);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async {
    final answer = Map<String, dynamic>.of(live); // as read when asked
    if (readGate != null) await readGate!.future;
    return right(answer);
  }

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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('writes run in order, so the last one made sets the switch', () async {
    final service = _Service();
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(radianceSettingsProvider);
    await _settle();
    final notifier = container.read(radianceSettingsProvider.notifier);

    final off = notifier.setProxyless(false);
    final on = notifier.setProxyless(true);
    await _settle();
    expect(service.patches, [false], reason: 'the second waits for the first');
    service.patchGates[0].complete();
    await off;
    await _settle();
    expect(service.patches, [false, true]);
    service.patchGates[1].complete();
    await on;
    expect(container.read(radianceSettingsProvider).proxyless, isTrue);
  });

  test('a settings read older than a write does not overwrite it', () async {
    final service = _Service()..readGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(radianceSettingsProvider); // the read starts, unset: on
    await _settle();
    final write = container
        .read(radianceSettingsProvider.notifier)
        .setProxyless(false);
    await _settle();
    service.patchGates[0].complete();
    await write;
    expect(container.read(radianceSettingsProvider).proxyless, isFalse);
    service.readGate!.complete(); // the older read lands
    await _settle();
    await _settle();
    expect(
      container.read(radianceSettingsProvider).proxyless,
      isFalse,
      reason: 'the read began before the write, so its answer is older',
    );
  });
}
