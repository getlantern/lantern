import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeStorage extends LocalStorageService {
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class _FakeLanternService implements LanternService {
  int autoFetches = 0;

  @override
  Future<Either<Failure, Server>> getAutoServerLocation() async {
    autoFetches += 1;
    return right(
      Server(
        tag: 'auto-tag',
        type: 'lantern',
        isLantern: true,
        location: GeoLocation(
          country: 'Japan',
          countryCode: 'JP',
          city: 'Tokyo',
          latitude: 0,
          longitude: 0,
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, ServerLocation>> getSelectedServerLocation() async =>
      left(Failure(error: 'unused', localizedErrorMessage: 'unused'));

  @override
  Future<void> updateWidgetLocation({
    required String city,
    required String country,
    required String countryCode,
    required String displayName,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await sl.reset();
    final storage = _FakeStorage();
    await storage.saveServerLocation(
      ServerLocation(
        serverName: 'manual-tag',
        serverType: ServerLocationType.lanternLocation.name,
      ),
    );
    sl.registerSingleton<LocalStorageService>(storage);
  });
  tearDown(sl.reset);

  test('switchToAuto fetches the resolved auto location', () async {
    final service = _FakeLanternService();
    final container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        vpnProvider.overrideWithValue(VPNStatus.connected),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(serverLocationProvider.notifier);
    await pumpEventQueue();
    service.autoFetches = 0;

    await notifier.switchToAuto();
    await pumpEventQueue();

    expect(service.autoFetches, 1);
    final location = container.read(serverLocationProvider);
    expect(location.serverType, ServerLocationType.auto.name);
    expect(location.autoLocation?.displayName, 'Japan - Tokyo');
  });
}
