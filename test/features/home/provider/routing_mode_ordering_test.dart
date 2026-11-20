import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

/// A service whose routing writes wait on completers the test controls.
class _Service implements LanternService {
  bool smart = false;
  bool fail = false;
  final writes = <bool>[];
  final gates = <Completer<void>>[];

  @override
  Future<Either<Failure, Unit>> setRoutingMode(bool smart) async {
    writes.add(smart);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    if (fail) return left(Failure(error: 'no', localizedErrorMessage: ''));
    this.smart = smart;
    return right(unit);
  }

  @override
  Future<Either<Failure, bool>> isSmartRoutingEnabled() async => right(smart);
  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isTelemetryEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isPeerProxyEnabled() async => right(false);
  @override
  Future<Either<Failure, bool>> isUnboundedEnabled() async => right(false);
  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async =>
      right(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<(RadianceSettings, ProviderContainer)> _start(_Service service) async {
  final container = ProviderContainer(
    overrides: [lanternServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  container.read(radianceSettingsProvider);
  await _settle();
  return (container.read(radianceSettingsProvider.notifier), container);
}

void main() {
  test(
    'routing writes run in order, so the last one asked for sticks',
    () async {
      final service = _Service();
      final (notifier, container) = await _start(service);

      final smart = notifier.setRoutingMode(RoutingMode.smart);
      final full = notifier.setRoutingMode(RoutingMode.full);
      expect(notifier.requestedRoutingMode, RoutingMode.full);
      await _settle();
      expect(service.writes, [true], reason: 'the second waits for the first');
      service.gates[0].complete();
      await smart;
      await _settle();
      expect(service.writes, [true, false]);
      expect(notifier.requestedRoutingMode, RoutingMode.full);
      service.gates[1].complete();
      await full;
      expect(
        container.read(radianceSettingsProvider).routingMode,
        RoutingMode.full,
      );
      expect(service.smart, isFalse);
      expect(notifier.requestedRoutingMode, RoutingMode.full);
    },
  );

  test(
    'a failed write leaves the requested mode at what is in effect',
    () async {
      final service = _Service()..fail = true;
      final (notifier, container) = await _start(service);
      final write = notifier.setRoutingMode(RoutingMode.smart);
      expect(notifier.requestedRoutingMode, RoutingMode.smart);
      await _settle();
      service.gates[0].complete();
      expect((await write).isLeft(), isTrue);
      expect(
        container.read(radianceSettingsProvider).routingMode,
        RoutingMode.full,
      );
      expect(notifier.requestedRoutingMode, RoutingMode.full);
    },
  );
}
