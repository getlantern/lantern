import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' show Either, Right;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/personal_proxies_section.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  int refreshes = 0;
  @override
  HelpersState build() => initial;
  @override
  Future<void> refreshIfUsed() async => refreshes++;
}

class _Status extends PersonalProxyStatusNotifier {
  int polls = 0;
  @override
  Map<String, PersonalProxyStatus>? build() => null;
  @override
  Future<void> poll() async => polls++;
}

class _Vpn extends VpnNotifier {
  final connects = <(ServerLocationType, String)>[];
  @override
  VPNStatus build() => VPNStatus.connected;
  @override
  Future<Either<Failure, String>> connectToServer(
    ServerLocationType location,
    String tag, {
    bool skipConflictCheck = false,
  }) async {
    connects.add((location, tag));
    return const Right('ok');
  }
}

class _Location extends ServerLocationNotifier {
  @override
  ServerLocation build() =>
      ServerLocation(serverName: '', serverType: ServerLocationType.auto.name);
  @override
  void updateServerLocation(ServerLocation entity) => state = entity;
  @override
  // Saves, then reports the request retired, so the screen stays put and no
  // router is needed.
  Future<bool> saveOnceConnected(FutureOr<void> Function() save) async {
    await save();
    return false;
  }
}

class _NoServers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers([]);
}

late _Helpers _notifier;
late _Status _status;

Future<void> _pump(WidgetTester tester, List<HelperPairingView> helpers) async {
  _status = _Status();
  _notifier = _Helpers(
    HelpersState(
      viewLoaded: true,
      view: HelpersView(unlocked: true, helpers: helpers),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(_NoServers.new),
        helpersProvider.overrideWith(() => _notifier),
        personalProxyStatusProvider.overrideWith(() => _status),
        serverLocationProvider.overrideWithValue(
          ServerLocation(
            serverName: '',
            serverType: ServerLocationType.auto.name,
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(body: PrivateServerLocationListView()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('personal proxies alone fill the Private Locations tab', (
    tester,
  ) async {
    await _pump(tester, const [
      HelperPairingView(pairingId: 'p1', name: 'Ali', online: true),
    ]);
    expect(find.byType(PersonalProxiesSection), findsOneWidget);
    expect(
      find.byKey(const Key('server_selection.personal_proxies')),
      findsOneWidget,
    );
    expect(find.text('no_private_server_setup_yet'.i18n), findsNothing);
  });

  testWidgets('the empty state shows without servers or personal proxies', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.text('no_private_server_setup_yet'.i18n), findsOneWidget);
    expect(
      find.byKey(const Key('server_selection.personal_proxies')),
      findsNothing,
    );
  });

  testWidgets('helper presence refreshes on the interval only while resumed', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _pump(tester, const [HelperPairingView(pairingId: 'p1')]);
    expect(_notifier.refreshes, 0);
    await tester.pump(personalProxiesRefreshInterval);
    expect(_notifier.refreshes, 1);
    await tester.pump(personalProxiesRefreshInterval);
    expect(_notifier.refreshes, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(personalProxiesRefreshInterval * 3);
    expect(_notifier.refreshes, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(personalProxiesRefreshInterval);
    expect(_notifier.refreshes, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(personalProxiesRefreshInterval);
    expect(_notifier.refreshes, 3);
  });

  testWidgets('no refresh timer without personal proxies', (tester) async {
    await _pump(tester, const []);
    await tester.pump(personalProxiesRefreshInterval * 2);
    expect(_notifier.refreshes, 0);
  });

  testWidgets("radiance's friend status is read on opening and on its "
      'interval, only while the tab shows friends and the app is resumed', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _pump(tester, const [HelperPairingView(pairingId: 'p1')]);
    expect(_status.polls, 1, reason: 'read once on opening');
    await tester.pump(personalProxyStatusInterval);
    expect(_status.polls, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(personalProxyStatusInterval * 3);
    expect(_status.polls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(personalProxyStatusInterval);
    expect(_status.polls, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(personalProxyStatusInterval * 3);
    expect(_status.polls, 3, reason: 'closing the list stops the poll');
  });

  testWidgets('no status poll without personal proxies', (tester) async {
    await _pump(tester, const []);
    await tester.pump(personalProxyStatusInterval * 3);
    expect(_status.polls, 0);
  });

  testWidgets('selecting a friend connects by their selection tag and '
      'saves them as the location', (tester) async {
    await sl.reset();
    final vpn = _Vpn();
    final location = _Location();
    final container = ProviderContainer(
      overrides: [
        availableServersProvider.overrideWith(_NoServers.new),
        helpersProvider.overrideWith(
          () => _Helpers(
            const HelpersState(
              viewLoaded: true,
              view: HelpersView(
                unlocked: true,
                helpers: [
                  HelperPairingView(
                    pairingId: 'p1',
                    name: 'Sara',
                    online: true,
                    outboundTag: 'helper-0123456789ab',
                  ),
                ],
              ),
            ),
          ),
        ),
        personalProxyStatusProvider.overrideWith(_Status.new),
        vpnProvider.overrideWith(() => vpn),
        serverLocationProvider.overrideWith(() => location),
        macosExtensionProvider.overrideWithValue(
          const MacOSExtensionState(SystemExtensionStatus.activated),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          child: GlobalLoaderOverlay(
            child: MaterialApp(
              theme: AppTheme.appTheme(),
              home: const Scaffold(body: PrivateServerLocationListView()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('server_selection.personal_proxy.p1')),
    );
    await tester.pump();
    await tester.pump();
    expect(vpn.connects, [
      (ServerLocationType.personalProxy, 'personal-proxy:helper-0123456789ab'),
    ]);
    final saved = container.read(serverLocationProvider);
    expect(saved.personalProxyFriendTag, 'helper-0123456789ab');
    expect(saved.countryCode, isEmpty);
  });
}
