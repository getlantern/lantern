import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  _FakeLanternService({AvailableServers? servers})
    : servers = servers ?? AvailableServers([]);

  AvailableServers servers;
  Completer<Either<Failure, AvailableServers>>? pendingFetch;
  final pendingFetchStarted = Completer<void>();
  int fetchCalls = 0;

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() {
    fetchCalls += 1;
    final pending = pendingFetch;
    if (pending != null) {
      if (!pendingFetchStarted.isCompleted) {
        pendingFetchStarted.complete();
      }
      return pending.future;
    }
    return Future.value(right(servers));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVPNStatusNotifier extends VPNStatusNotifier {
  _FakeVPNStatusNotifier(this._stream);

  final Stream<LanternStatus> _stream;

  @override
  Stream<LanternStatus> build() => _stream;
}

class _FakeServerLocationNotifier extends ServerLocationNotifier {
  final pushedLocations = <ServerLocation>[];

  @override
  ServerLocation build() => ServerLocation(
    serverName: '',
    serverType: ServerLocationType.auto.name,
    autoLocation: const AutoLocation(
      country: 'Germany',
      countryCode: 'DE',
      displayName: 'Germany - Berlin',
      tag: 'old-tag',
    ),
  );

  @override
  void updateServerLocation(ServerLocation entity) {
    pushedLocations.add(entity);
  }
}

Server _fastestLanternServer() => Server(
  tag: 'fastest-tag',
  type: 'lantern',
  isLantern: true,
  location: GeoLocation(
    country: 'United States',
    countryCode: 'US',
    city: 'New York',
    latitude: 0,
    longitude: 0,
  ),
  selectionHistory: SelectionHistory(lastSuccessDelayMs: 42),
);

/// Builds the notifier with the given VPN status (null = no status event
/// yet) and returns the recorded Smart Location pushes.
Future<List<ServerLocation>> _pushesForVpnStatus(VPNStatus? status) async {
  final service = _FakeLanternService(
    servers: AvailableServers([_fastestLanternServer()]),
  );
  final locationNotifier = _FakeServerLocationNotifier();
  final statusStream = status == null
      ? StreamController<LanternStatus>().stream
      : Stream.value(LanternStatus(status: status));
  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      vPNStatusProvider.overrideWith(() => _FakeVPNStatusNotifier(statusStream)),
      serverLocationProvider.overrideWith(() => locationNotifier),
    ],
  );
  addTearDown(container.dispose);

  // Riverpod pauses a provider's stream subscription while it has no
  // listeners, so attach one before awaiting the first status event.
  container.listen(vPNStatusProvider, (_, _) {});
  if (status != null) {
    await container.read(vPNStatusProvider.future);
  }
  await container.read(availableServersProvider.future);
  return locationNotifier.pushedLocations;
}

void main() {
  test(
    'probe-settle refresh stops when disposed during the first fetch',
    () async {
      final service = _FakeLanternService();
      final container = ProviderContainer(
        overrides: [lanternServiceProvider.overrideWithValue(service)],
      );

      await container.read(availableServersProvider.future);
      final notifier = container.read(availableServersProvider.notifier);
      final pending = Completer<Either<Failure, AvailableServers>>();
      service.pendingFetch = pending;

      final refresh = notifier.refreshAvailableServersAfterProbeSettle();
      await service.pendingFetchStarted.future;
      container.dispose();
      pending.complete(right(AvailableServers([])));

      await expectLater(refresh.timeout(const Duration(seconds: 2)), completes);
      expect(service.fetchCalls, 2);
    },
  );

  group('Smart Location push VPN-status guard', () {
    test('pushes fastest server when VPN is disconnected', () async {
      final pushes = await _pushesForVpnStatus(VPNStatus.disconnected);
      expect(pushes, hasLength(1));
      expect(pushes.single.autoLocation?.tag, 'fastest-tag');
    });

    test('skips push when permission is missing', () async {
      final pushes = await _pushesForVpnStatus(VPNStatus.missingPermission);
      expect(pushes, isEmpty);
    });

    test('skips push when no status event has arrived yet', () async {
      final pushes = await _pushesForVpnStatus(null);
      expect(pushes, isEmpty);
    });

    test('skips push when VPN is connected', () async {
      final pushes = await _pushesForVpnStatus(VPNStatus.connected);
      expect(pushes, isEmpty);
    });

    test('skips push when VPN is connecting', () async {
      final pushes = await _pushesForVpnStatus(VPNStatus.connecting);
      expect(pushes, isEmpty);
    });

    test('skips push when VPN is disconnecting', () async {
      final pushes = await _pushesForVpnStatus(VPNStatus.disconnecting);
      expect(pushes, isEmpty);
    });

    test('skips push when VPN status is error', () async {
      final pushes = await _pushesForVpnStatus(VPNStatus.error);
      expect(pushes, isEmpty);
    });
  });
}
