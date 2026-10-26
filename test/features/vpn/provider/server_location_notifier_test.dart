import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
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

class _FakeStorage extends LocalStorageService {
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _FakeVpn extends VpnNotifier {
  @override
  VPNStatus build() => VPNStatus.disconnected;

  void set(VPNStatus status) => state = status;
}

ServerLocation _location(String tag) => ServerLocation(
  serverType: ServerLocationType.lanternLocation.name,
  serverName: tag,
  displayName: tag,
  protocol: '',
  city: tag,
);

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeStorage storage;

  setUp(() async {
    await sl.reset();
    storage = _FakeStorage();
    sl.registerSingleton<LocalStorageService>(storage);
    container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(_FakeLanternService()),
        vpnProvider.overrideWith(_FakeVpn.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(sl.reset);
    // Build while disconnected so the startup refresh skips the stubbed service.
    container.read(serverLocationProvider);
  });

  ServerLocationNotifier notifier() =>
      container.read(serverLocationProvider.notifier);
  _FakeVpn vpn() => container.read(vpnProvider.notifier) as _FakeVpn;

  group('saveOnceConnected', () {
    test('saves immediately when already connected', () async {
      vpn().set(VPNStatus.connected);
      final saved = await notifier().saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );

      expect(saved, isTrue);
      expect(container.read(serverLocationProvider).serverName, 'a');
    });

    test('defers the save until the VPN reports connected', () async {
      final result = notifier().saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );
      await _pump();
      expect(container.read(serverLocationProvider).serverName, isNot('a'));

      vpn().set(VPNStatus.connecting);
      await _pump();
      expect(container.read(serverLocationProvider).serverName, isNot('a'));

      vpn().set(VPNStatus.connected);
      expect(await result, isTrue);
      expect(container.read(serverLocationProvider).serverName, 'a');
      expect(storage.getServerLocation()?.serverName, 'a');
    });

    test('drops the pending save when the VPN errors', () async {
      final result = notifier().saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );
      vpn().set(VPNStatus.error);
      expect(await result, isFalse);

      // A later connection must not resurrect the failed request.
      vpn().set(VPNStatus.connected);
      await _pump();
      expect(container.read(serverLocationProvider).serverName, isNot('a'));
    });

    test('a newer request retires the pending one', () async {
      final first = notifier().saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );
      final second = notifier().saveOnceConnected(
        () => notifier().updateServerLocation(_location('b')),
      );
      expect(await first, isFalse);

      vpn().set(VPNStatus.connected);
      expect(await second, isTrue);
      expect(container.read(serverLocationProvider).serverName, 'b');
    });

    test('still resolves when the save itself throws', () async {
      vpn().set(VPNStatus.connected);
      final saved = await notifier().saveOnceConnected(
        () => throw StateError('disk full'),
      );
      expect(saved, isTrue);
    });
  });
}
