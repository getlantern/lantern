import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  Either<Failure, bool> connected = right(false);

  // HomeNotifier.build() waits on this; leaving it pending keeps the user
  // load (and its side effects) out of these tests.
  @override
  Future<void> waitForRadiance() => Completer<void>().future;

  @override
  Future<Either<Failure, bool>> isVPNConnected() async => connected;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVpnNotifier extends VpnNotifier {
  _FakeVpnNotifier(this._initial);

  final VPNStatus _initial;
  int startCalls = 0;
  Completer<Either<Failure, String>> switchResult = Completer();

  @override
  VPNStatus build() => _initial;

  void setStatus(VPNStatus status) => state = status;

  @override
  Future<Either<Failure, String>> startVPN({
    bool force = false,
    bool skipConflictCheck = false,
  }) {
    expect(force, isTrue);
    startCalls += 1;
    return switchResult.future;
  }
}

class _FakeServerLocationNotifier extends ServerLocationNotifier {
  @override
  ServerLocation build() => ServerLocation(
    serverName: 'manual-tag',
    serverType: ServerLocationType.lanternLocation.name,
    country: 'Germany',
    city: 'Berlin',
  );

  @override
  void updateServerLocation(ServerLocation entity) => state = entity;
}

typedef _Harness = ({
  ProviderContainer container,
  _FakeLanternService service,
  _FakeVpnNotifier vpn,
  void Function() allowSelection,
});

_Harness _harness(VPNStatus vpnStatus) {
  final service = _FakeLanternService();
  final vpn = _FakeVpnNotifier(vpnStatus);
  var canSelect = false;
  final container = ProviderContainer(
    overrides: [
      canSelectServerProvider.overrideWith((ref) => canSelect),
      lanternServiceProvider.overrideWithValue(service),
      vpnProvider.overrideWith(() => vpn),
      serverLocationProvider.overrideWith(_FakeServerLocationNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  // Build the fakes before HomeNotifier reads them.
  container.read(vpnProvider);
  container.read(serverLocationProvider);
  return (
    container: container,
    service: service,
    vpn: vpn,
    allowSelection: () {
      canSelect = true;
      container.invalidate(canSelectServerProvider);
    },
  );
}

ServerLocationType _savedType(ProviderContainer container) =>
    container.read(serverLocationProvider).serverType.toServerLocationType;

void main() {
  test(
    'disconnected: saves smart location without touching the tunnel',
    () async {
      final h = _harness(VPNStatus.disconnected);

      await h.container.read(homeProvider.notifier).resetServerLocation();

      expect(h.vpn.startCalls, 0);
      expect(_savedType(h.container), ServerLocationType.auto);
    },
  );

  test('connected: switches the tunnel before saving smart location', () async {
    final h = _harness(VPNStatus.connected);
    h.service.connected = right(true);

    final reset = h.container.read(homeProvider.notifier).resetServerLocation();
    await pumpEventQueue();
    expect(h.vpn.startCalls, 1);
    expect(_savedType(h.container), ServerLocationType.lanternLocation);

    h.vpn.switchResult.complete(right('ok'));
    await reset;
    expect(_savedType(h.container), ServerLocationType.auto);
  });

  test('connected: keeps the manual location when the switch fails', () async {
    final h = _harness(VPNStatus.connected);
    h.service.connected = right(true);
    h.vpn.switchResult.complete(
      left(Failure(error: 'x', localizedErrorMessage: 'x')),
    );

    await h.container.read(homeProvider.notifier).resetServerLocation();

    expect(h.vpn.startCalls, 1);
    expect(_savedType(h.container), ServerLocationType.lanternLocation);
  });

  test('skips the reset when native status is unavailable', () async {
    final h = _harness(VPNStatus.disconnected);
    h.service.connected = left(Failure(error: 'x', localizedErrorMessage: 'x'));

    await h.container.read(homeProvider.notifier).resetServerLocation();

    expect(h.vpn.startCalls, 0);
    expect(_savedType(h.container), ServerLocationType.lanternLocation);
  });

  test('concurrent resets share one switch', () async {
    final h = _harness(VPNStatus.connected);
    h.service.connected = right(true);
    final notifier = h.container.read(homeProvider.notifier);

    final first = notifier.resetServerLocation();
    final second = notifier.resetServerLocation();
    await pumpEventQueue();
    h.vpn.switchResult.complete(right('ok'));
    await Future.wait([first, second]);

    expect(h.vpn.startCalls, 1);
    expect(_savedType(h.container), ServerLocationType.auto);
  });

  test('does not overwrite a location the user picks mid-reset', () async {
    final h = _harness(VPNStatus.connected);
    h.service.connected = right(true);

    final reset = h.container.read(homeProvider.notifier).resetServerLocation();
    await pumpEventQueue();
    final privateServer = ServerLocation(
      serverName: 'my-private-server',
      serverType: ServerLocationType.privateServer.name,
    );
    h.container
        .read(serverLocationProvider.notifier)
        .updateServerLocation(privateServer);
    h.vpn.switchResult.complete(right('ok'));
    await reset;

    expect(_savedType(h.container), ServerLocationType.privateServer);
  });

  test('stops if the user may choose servers again mid-reset', () async {
    final h = _harness(VPNStatus.connecting);
    h.service.connected = right(true);
    h.vpn.switchResult.complete(right('ok'));

    final reset = h.container.read(homeProvider.notifier).resetServerLocation();
    await pumpEventQueue();
    h.allowSelection();
    h.vpn.setStatus(VPNStatus.connected);
    await reset;

    expect(h.vpn.startCalls, 0);
    expect(_savedType(h.container), ServerLocationType.lanternLocation);
  });

  test('waits for a pending connect to settle before acting', () async {
    final h = _harness(VPNStatus.connecting);
    h.service.connected = right(true);
    h.vpn.switchResult.complete(right('ok'));

    final reset = h.container.read(homeProvider.notifier).resetServerLocation();
    await pumpEventQueue();
    expect(h.vpn.startCalls, 0);
    expect(_savedType(h.container), ServerLocationType.lanternLocation);

    h.vpn.setStatus(VPNStatus.connected);
    await reset;
    expect(h.vpn.startCalls, 1);
    expect(_savedType(h.container), ServerLocationType.auto);
  });
}
