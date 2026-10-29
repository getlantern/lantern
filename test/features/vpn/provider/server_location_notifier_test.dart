import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
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

class _Storage implements LocalStorageService {
  ServerLocation? location;

  @override
  ServerLocation? getServerLocation() => location;

  @override
  Future<void> saveServerLocation(ServerLocation l) async => location = l;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Helpers extends HelpersNotifier {
  @override
  HelpersState build() => const HelpersState();

  void set(HelpersState s) => state = s;
}

const _oneHelper = HelpersState(
  viewLoaded: true,
  view: HelpersView(
    unlocked: true,
    helpers: [HelperPairingView(pairingId: 'p1')],
  ),
);

const _noHelpers = HelpersState(
  viewLoaded: true,
  view: HelpersView(unlocked: true),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late _Helpers helpers;

  ProviderContainer container() {
    helpers = _Helpers();
    final c = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(_Service()),
        helpersProvider.overrideWith(() => helpers),
        vpnProvider.overrideWithValue(VPNStatus.disconnected),
      ],
    );
    addTearDown(c.dispose);
    c.read(helpersProvider);
    return c;
  }

  setUp(() {
    storage = _Storage();
    sl.registerSingleton<LocalStorageService>(storage);
  });
  tearDown(() => sl.reset());

  test(
    'the personal proxy selection becomes auto when the last helper goes',
    () async {
      storage.location = ServerLocation.personalProxy();
      final c = container();
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.personalProxy.name,
      );
      helpers.set(_oneHelper);
      await pumpEventQueue();
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.personalProxy.name,
      );
      helpers.set(_noHelpers);
      await pumpEventQueue();
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.auto.name,
      );
      expect(storage.location!.serverType, ServerLocationType.auto.name);
    },
  );

  test(
    'a view already loaded empty drops the personal proxy selection',
    () async {
      storage.location = ServerLocation.personalProxy();
      final c = container();
      helpers.set(_noHelpers);
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.personalProxy.name,
      );
      await pumpEventQueue();
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.auto.name,
      );
      expect(storage.location!.serverType, ServerLocationType.auto.name);
    },
  );

  test('an unloaded view does not drop the selection', () async {
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(const HelpersState(error: 'unavailable'));
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.personalProxy.name,
    );
  });

  test('another selection is left alone when helpers go', () async {
    storage.location = ServerLocation(
      serverType: ServerLocationType.lanternLocation.name,
      serverName: 'fra',
      displayName: 'Germany',
      protocol: '',
      city: 'Frankfurt',
    );
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(_noHelpers);
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.lanternLocation.name,
    );
  });
}
