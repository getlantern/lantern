import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  final statusController = StreamController<LanternStatus>.broadcast();

  Either<Failure, bool> isConnectedResult = right(false);
  int isVPNConnectedCalls = 0;
  int startVPNCalls = 0;
  int stopVPNCalls = 0;

  @override
  Future<Either<Failure, bool>> isVPNConnected() async {
    isVPNConnectedCalls += 1;
    return isConnectedResult;
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => statusController.stream;

  @override
  Future<Either<Failure, String>> startVPN() async {
    startVPNCalls += 1;
    return right('ok');
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    stopVPNCalls += 1;
    return right('ok');
  }

  @override
  Future<bool> checkVpnConflict() async => false;

  @override
  Future<bool> isTagAvailable(String tag) async => true;

  Future<void> dispose() => statusController.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_FakeLanternService service) {
  return ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      serverLocationProvider.overrideWithValue(initialServerLocation()),
    ],
  );
}

Future<void> _pumpProviderQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('VpnNotifier', () {
    test('hydrates initial connected state from core', () async {
      final service = _FakeLanternService()..isConnectedResult = right(true);
      final container = _container(service);
      addTearDown(container.dispose);
      addTearDown(service.dispose);

      expect(container.read(vpnProvider), VPNStatus.disconnected);

      await _pumpProviderQueue();

      expect(service.isVPNConnectedCalls, 1);
      expect(container.read(vpnProvider), VPNStatus.connected);
    });

    test(
      'starts VPN from an error state because the switch displays off',
      () async {
        final service = _FakeLanternService();
        final container = _container(service);
        addTearDown(container.dispose);
        addTearDown(service.dispose);
        final statusSub = container.listen<AsyncValue<LanternStatus>>(
          vPNStatusProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(statusSub.close);

        container.read(vpnProvider);
        await _pumpProviderQueue();
        service.statusController.add(
          LanternStatus(status: VPNStatus.error, error: 'connect failed'),
        );
        await _pumpProviderQueue();

        expect(container.read(vpnProvider), VPNStatus.error);

        final result = await container
            .read(vpnProvider.notifier)
            .onVPNStateChange();

        expect(result.isRight(), isTrue);
        expect(service.startVPNCalls, 1);
        expect(service.stopVPNCalls, 0);
      },
    );

    test(
      'status stream errors become VPNStatus.error instead of crashing',
      () async {
        final service = _FakeLanternService();
        final container = _container(service);
        addTearDown(container.dispose);
        addTearDown(service.dispose);
        final statusSub = container.listen<AsyncValue<LanternStatus>>(
          vPNStatusProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(statusSub.close);

        container.read(vpnProvider);
        await _pumpProviderQueue();
        service.statusController.addError(StateError('status stream failed'));
        await _pumpProviderQueue();

        expect(container.read(vpnProvider), VPNStatus.error);
        final status = container.read(vPNStatusProvider);
        expect(status.hasValue, isTrue);
        expect(status.value?.status, VPNStatus.error);
        expect(status.value?.error, contains('status stream failed'));
      },
    );
  });
}
