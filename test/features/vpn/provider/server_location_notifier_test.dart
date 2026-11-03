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

  /// The selected_server op's answers, one per read, in the order the reads
  /// start.
  final selectedServer = <Completer<String>>[];

  @override
  Future<Either<Failure, String>> helperCall(
    String op,
    Map<String, dynamic> args,
  ) async {
    final answer = Completer<String>();
    selectedServer.add(answer);
    return Right(await answer.future);
  }

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

ServerLocation _location(String tag) => ServerLocation(
  serverType: ServerLocationType.lanternLocation.name,
  serverName: tag,
  displayName: tag,
);

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

  test('switching to auto forgets the server that was selected', () async {
    storage.location = ServerLocation(
      serverType: ServerLocationType.privateServer.name,
      serverName: 'private',
      city: 'Amsterdam',
    );
    final c = container(vpn: VPNStatus.disconnected);
    c.read(serverLocationProvider);
    await c.read(serverLocationProvider.notifier).switchToAuto();
    final shown = c.read(serverLocationProvider);
    expect(shown.serverType, ServerLocationType.auto.name);
    expect(shown.serverName, isEmpty);
    expect(storage.location!.serverName, isEmpty);
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

  group('syncSelection', () {
    const friend = 'helper-0123456789ab';
    final friendTag = personalProxySelection(friend);

    Future<void> answer(int i, String json) async {
      service.selectedServer[i].complete(json);
      await Future<void>.delayed(Duration.zero);
    }

    test('only the newest started read applies, whatever order the answers '
        'come in', () async {
      final c = container();
      final notifier = c.read(serverLocationProvider.notifier);
      final older = notifier.syncSelection();
      final newer = notifier.syncSelection();
      await Future<void>.delayed(Duration.zero);
      await answer(1, '{"tag":"$friendTag"}');
      await answer(0, '{"tag":"$personalProxiesTag"}');
      await Future.wait([older, newer]);
      expect(c.read(serverLocationProvider).personalProxyFriendTag, friend);
    });

    test('mirrors the group, a friend and auto', () async {
      storage.location = ServerLocation.personalProxy(friendTag: friend);
      final c = container();
      final notifier = c.read(serverLocationProvider.notifier);

      var sync = notifier.syncSelection();
      await answer(0, '{"tag":"$personalProxiesTag"}');
      await sync;
      expect(c.read(serverLocationProvider).serverName, personalProxiesTag);
      expect(storage.location!.serverName, personalProxiesTag);

      sync = notifier.syncSelection();
      await answer(1, '{"tag":"$friendTag"}');
      await sync;
      expect(c.read(serverLocationProvider).personalProxyFriendTag, friend);

      sync = notifier.syncSelection();
      await answer(2, '{"tag":"auto"}');
      await sync;
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.auto.name,
      );
    });

    test('acknowledged before the switch: the read after the connect sees A, '
        'the selection-changed read sees B, and B is shown', () async {
      const a = 'helper-aaaaaaaaaaaa';
      storage.location = ServerLocation.personalProxy(friendTag: a);
      final c = container(vpn: VPNStatus.connected);
      final notifier = c.read(serverLocationProvider.notifier);
      final afterConnect = notifier.syncSelection();
      await answer(0, '{"tag":"${personalProxySelection(a)}"}');
      await afterConnect;
      expect(c.read(serverLocationProvider).personalProxyFriendTag, a);
      final onEvent = notifier.syncSelection();
      await answer(1, '{"tag":"$friendTag"}');
      await onEvent;
      expect(c.read(serverLocationProvider).personalProxyFriendTag, friend);
    });

    test('friend, then auto, then the same friend: the friend is shown '
        'again', () async {
      storage.location = ServerLocation.personalProxy(friendTag: friend);
      final c = container();
      final notifier = c.read(serverLocationProvider.notifier);
      var sync = notifier.syncSelection();
      await answer(0, '{"tag":"auto"}');
      await sync;
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.auto.name,
      );
      sync = notifier.syncSelection();
      await answer(1, '{"tag":"$friendTag"}');
      await sync;
      expect(c.read(serverLocationProvider).personalProxyFriendTag, friend);
      expect(
        c.read(serverLocationProvider).serverType,
        ServerLocationType.personalProxy.name,
      );
    });

    test('duplicate events do not flap the selection', () async {
      storage.location = ServerLocation.personalProxy();
      final c = container();
      final notifier = c.read(serverLocationProvider.notifier);
      final shown = <String>[];
      c.listen(serverLocationProvider, (_, next) => shown.add(next.serverName));
      final reads = [for (var i = 0; i < 3; i++) notifier.syncSelection()];
      await Future<void>.delayed(Duration.zero);
      await answer(2, '{"tag":"$friendTag"}');
      await answer(0, '{"tag":"$friendTag"}');
      await answer(1, '{"tag":"$friendTag"}');
      await Future.wait(reads);
      expect(shown, [friendTag], reason: 'one change, no flapping');
    });

    test('a Lantern server the screen saved keeps its details', () async {
      final c = container(vpn: VPNStatus.connected);
      final notifier = c.read(serverLocationProvider.notifier);
      final screenSave = _location(
        'lantern-1',
      ).copyWith(city: 'Berlin', countryCode: 'DE');
      notifier.updateServerLocation(screenSave);
      final sync = notifier.syncSelection();
      await answer(0, '{"tag":"lantern-1"}');
      await sync;
      final loc = c.read(serverLocationProvider);
      expect(loc.serverName, 'lantern-1');
      expect(loc.city, 'Berlin');
    });

    test('a failed read changes nothing', () async {
      storage.location = ServerLocation.personalProxy(friendTag: friend);
      final c = container();
      final sync = c.read(serverLocationProvider.notifier).syncSelection();
      await answer(0, '{"error":"unavailable"}');
      await sync;
      expect(c.read(serverLocationProvider).personalProxyFriendTag, friend);
    });

    test('another server is fetched with its details', () async {
      final c = container(vpn: VPNStatus.connected);
      final sync = c.read(serverLocationProvider.notifier).syncSelection();
      await answer(0, '{"tag":"lantern-1"}');
      service.selected.complete(Right(_location('lantern-1')));
      await sync;
      expect(c.read(serverLocationProvider).serverName, 'lantern-1');
    });
  });
}
