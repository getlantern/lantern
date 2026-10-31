import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/helper_tags.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  bool tagAvailable = false;
  final widgetServers = <String>[];

  @override
  Future<bool> isTagAvailable(String tag) async => tagAvailable;

  final auto = Completer<Either<Failure, Server>>();
  final selected = Completer<Either<Failure, ServerLocation>>();

  @override
  Future<Either<Failure, Server>> getAutoServerLocation() => auto.future;

  @override
  Future<Either<Failure, ServerLocation>> getSelectedServerLocation() =>
      selected.future;

  @override
  Future<void> updateWidgetLocation({
    required String city,
    required String country,
    required String countryCode,
    required String displayName,
    required String serverName,
  }) async => widgetServers.add(serverName);

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
  HelpersState? afterRefresh;
  int refreshes = 0;

  @override
  HelpersState build() => const HelpersState();

  void set(HelpersState s) => state = s;

  @override
  Future<void> refreshIfUsed() async {
    refreshes++;
    if (afterRefresh != null) state = afterRefresh!;
  }
}

class _Servers extends AvailableServersNotifier {
  @override
  Future<Either<Failure, AvailableServers>> fetchAvailableServers() async =>
      Right(AvailableServers([]));
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
  late _Service service;

  ProviderContainer container({VPNStatus vpn = VPNStatus.disconnected}) {
    helpers = _Helpers();
    final c = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        helpersProvider.overrideWith(() => helpers),
        vpnProvider.overrideWithValue(vpn),
        availableServersProvider.overrideWith(_Servers.new),
      ],
    );
    addTearDown(c.dispose);
    c.read(helpersProvider);
    return c;
  }

  setUp(() {
    storage = _Storage();
    service = _Service();
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

  test('an empty view after a keystore reset keeps the selection', () async {
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(
      const HelpersState(
        viewLoaded: true,
        keystoreReset: true,
        view: HelpersView(unlocked: true),
      ),
    );
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.personalProxy.name,
    );
    expect(storage.location!.serverType, ServerLocationType.personalProxy.name);
  });

  test('an empty view keeps the selection while the group exists', () async {
    service.tagAvailable = true;
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(_noHelpers);
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.personalProxy.name,
    );
    expect(storage.location!.serverType, ServerLocationType.personalProxy.name);
  });

  test('an empty view with the group gone switches to auto', () async {
    service.tagAvailable = false;
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(_noHelpers);
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.auto.name,
    );
    expect(storage.location!.serverType, ServerLocationType.auto.name);
  });

  test('a server list refresh after the group goes switches to auto', () async {
    service.tagAvailable = true;
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(_oneHelper);
    await pumpEventQueue();
    helpers.set(_noHelpers);
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.personalProxy.name,
    );

    service.tagAvailable = false;
    await c
        .read(availableServersProvider.notifier)
        .forceFetchAvailableServers();
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.auto.name,
    );
    expect(storage.location!.serverType, ServerLocationType.auto.name);
  });

  test(
    'a server list refresh keeps the selection while helpers remain',
    () async {
      storage.location = ServerLocation.personalProxy();
      final c = container();
      c.read(serverLocationProvider);
      helpers.set(_oneHelper);
      await c
          .read(availableServersProvider.notifier)
          .forceFetchAvailableServers();
      await pumpEventQueue();
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.personalProxy.name,
      );
    },
  );

  test('a config refresh with a stale helper list refreshes it and switches '
      'to auto once the friend is gone', () async {
    service.tagAvailable = true;
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(_oneHelper);
    await c.read(availableServersProvider.future);
    await pumpEventQueue();

    service.tagAvailable = false;
    helpers.afterRefresh = _noHelpers;
    await c
        .read(availableServersProvider.notifier)
        .forceFetchAvailableServers();
    await pumpEventQueue();
    expect(helpers.refreshes, 1);
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.auto.name,
    );
    expect(storage.location!.serverType, ServerLocationType.auto.name);
  });

  test('a config refresh keeps the selection when the refreshed list still '
      'has the friend', () async {
    service.tagAvailable = true;
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(_oneHelper);
    await c.read(availableServersProvider.future);
    await pumpEventQueue();

    service.tagAvailable = false;
    helpers.afterRefresh = _oneHelper;
    await c
        .read(availableServersProvider.notifier)
        .forceFetchAvailableServers();
    await pumpEventQueue();
    expect(helpers.refreshes, 1);
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.personalProxy.name,
    );
  });

  test('a config refresh after a keystore reset neither refreshes nor '
      'switches', () async {
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    helpers.set(
      const HelpersState(
        viewLoaded: true,
        keystoreReset: true,
        view: HelpersView(
          unlocked: true,
          helpers: [HelperPairingView(pairingId: 'p1')],
        ),
      ),
    );
    helpers.afterRefresh = _noHelpers;
    await c
        .read(availableServersProvider.notifier)
        .forceFetchAvailableServers();
    await pumpEventQueue();
    expect(helpers.refreshes, 0);
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.personalProxy.name,
    );
  });

  final frankfurt = ServerLocation(
    serverType: ServerLocationType.lanternLocation.name,
    serverName: 'fra',
    displayName: 'Germany',
    protocol: '',
    city: 'Frankfurt',
  );

  test('a selected-location fetch finishing after the switch to auto does '
      'not restore the personal proxy', () async {
    storage.location = ServerLocation.personalProxy();
    final c = container(vpn: VPNStatus.connected);
    c.read(serverLocationProvider);
    await c.read(serverLocationProvider.notifier).switchToAuto();
    service.selected.complete(Right(ServerLocation.personalProxy()));
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.auto.name,
    );
    expect(storage.location!.serverType, ServerLocationType.auto.name);
  });

  test('an auto fetch finishing after a newer selection does not replace '
      'it', () async {
    storage.location = ServerLocation.personalProxy();
    final c = container(vpn: VPNStatus.connected);
    c.read(serverLocationProvider);
    service.selected.complete(Right(ServerLocation.personalProxy()));
    await pumpEventQueue();
    helpers.set(_noHelpers);
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.auto.name,
    );
    c.read(serverLocationProvider.notifier).updateServerLocation(frankfurt);
    service.auto.complete(
      Right(
        Server(
          tag: 'fastest',
          type: 'lantern',
          isLantern: true,
          location: GeoLocation(
            country: 'United States',
            countryCode: 'US',
            city: 'New York',
            latitude: 0,
            longitude: 0,
          ),
        ),
      ),
    );
    await pumpEventQueue();
    expect(c.read(serverLocationProvider).serverName, 'fra');
    expect(storage.location!.serverName, 'fra');
  });

  test('dropping the personal proxy points the widget back at auto', () async {
    storage.location = ServerLocation.personalProxy();
    final c = container();
    c.read(serverLocationProvider);
    expect(service.widgetServers.last, personalProxiesTag);
    helpers.set(_noHelpers);
    await pumpEventQueue();
    expect(
      c.read(serverLocationProvider).serverType,
      ServerLocationType.auto.name,
    );
    expect(service.widgetServers.last, '');
  });

  test('the widget ends on the selection the app made last', () async {
    final c = container();
    final notifier = c.read(serverLocationProvider.notifier);
    // A server-location event for auto lands mid-switch, then the switch
    // to personal proxies completes.
    notifier.updateServerLocation(
      ServerLocation(
        serverType: ServerLocationType.auto.name,
        serverName: '',
        displayName: '',
        protocol: '',
        city: 'Frankfurt',
      ),
    );
    notifier.updateServerLocation(ServerLocation.personalProxy());
    await pumpEventQueue();
    expect(service.widgetServers.last, personalProxiesTag);

    notifier.updateServerLocation(frankfurt);
    await pumpEventQueue();
    expect(service.widgetServers.last, 'fra');
  });

  group('personalProxyFellBack', () {
    const friend = 'helper-0123456789ab';

    test('the selected friend falls back to the group', () async {
      storage.location = ServerLocation.personalProxy(friendTag: friend);
      final c = container(vpn: VPNStatus.connected);
      await c
          .read(serverLocationProvider.notifier)
          .personalProxyFellBack(friend, personalProxiesTag);
      final loc = c.read(serverLocationProvider);
      expect(loc.serverName, personalProxiesTag);
      expect(loc.personalProxyFriendTag, isNull);
      expect(storage.location!.serverName, personalProxiesTag);
    });

    test('or to Smart Location', () async {
      storage.location = ServerLocation.personalProxy(friendTag: friend);
      final c = container();
      await c
          .read(serverLocationProvider.notifier)
          .personalProxyFellBack(friend, 'auto');
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.auto.name,
      );
    });

    test('a selection that is no longer that friend is left alone', () async {
      storage.location = ServerLocation.personalProxy(
        friendTag: 'helper-ffffffffffff',
      );
      final c = container();
      await c
          .read(serverLocationProvider.notifier)
          .personalProxyFellBack(friend, 'auto');
      expect(
        c.read(serverLocationProvider).personalProxyFriendTag,
        'helper-ffffffffffff',
      );
    });
  });
}
