import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _activeTag = 'shadowsocks-out-active';
const _fastestTag = 'hysteria2-out-fastest';

Server _server(String tag, String city, int delayMs) => Server(
  tag: tag,
  type: tag.split('-').first,
  isLantern: true,
  location: GeoLocation(
    country: 'United States',
    countryCode: 'US',
    city: city,
    latitude: 0,
    longitude: 0,
  ),
  selectionHistory: SelectionHistory(lastSuccessDelayMs: delayMs),
);

/// Fastest-by-probe is [_fastestTag]; [_activeTag] is slower, standing in for
/// the server auto-select actually routes through.
final _servers = AvailableServers([
  _server(_activeTag, 'Ashburn', 400),
  _server(_fastestTag, 'Los Angeles', 100),
]);

ServerLocation _autoLocation(String tag, String city) => ServerLocation(
  serverType: ServerLocationType.auto.name,
  serverName: '',
  displayName: '',
  protocol: '',
  city: city,
  autoLocation: AutoLocation(
    country: 'United States',
    countryCode: 'US',
    displayName: 'United States - $city',
    tag: tag,
  ),
);

class _FakeStorage implements LocalStorageService {
  _FakeStorage(this.location);

  ServerLocation? location;

  @override
  ServerLocation? getServerLocation() => location;

  @override
  Future<void> saveServerLocation(ServerLocation value) async {
    location = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLanternService implements LanternService {
  @override
  Future<Either<Failure, AvailableServers>>
  getLanternAvailableServers() async => right(_servers);

  /// The notifier under test must not depend on this; returning a failure keeps
  /// [ServerLocationNotifier]'s own refresh from touching the location.
  @override
  Future<Either<Failure, Server>> getAutoServerLocation() async =>
      left(Failure(error: 'unavailable', localizedErrorMessage: 'unavailable'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(VPNStatus status) => ProviderContainer(
  overrides: [
    lanternServiceProvider.overrideWithValue(_FakeLanternService()),
    vpnProvider.overrideWithValue(status),
  ],
);

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<LocalStorageService>(
      _FakeStorage(_autoLocation(_activeTag, 'Ashburn')),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  test(
    'connected: a server-list refresh leaves the active location alone',
    () async {
      final container = _container(VPNStatus.connected);
      addTearDown(container.dispose);

      await container.read(availableServersProvider.future);
      await container
          .read(availableServersProvider.notifier)
          .forceFetchAvailableServers();

      expect(
        container.read(serverLocationProvider).autoLocation?.tag,
        _activeTag,
        reason:
            'while connected radiance owns the Smart Location; the fastest-probed '
            'server must not overwrite the server traffic actually exits from',
      );
    },
  );

  test(
    'connecting: a server-list refresh leaves the active location alone',
    () async {
      final container = _container(VPNStatus.connecting);
      addTearDown(container.dispose);

      await container.read(availableServersProvider.future);

      expect(
        container.read(serverLocationProvider).autoLocation?.tag,
        _activeTag,
      );
    },
  );

  test(
    'disconnected: the fastest-probed server seeds the Smart Location',
    () async {
      final container = _container(VPNStatus.disconnected);
      addTearDown(container.dispose);

      await container.read(availableServersProvider.future);

      expect(
        container.read(serverLocationProvider).autoLocation?.tag,
        _fastestTag,
      );
    },
  );
}
