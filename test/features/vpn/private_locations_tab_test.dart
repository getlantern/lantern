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
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

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
  _Vpn([this.status = VPNStatus.connected]);
  final VPNStatus status;
  final connects = <(ServerLocationType, String)>[];

  /// Runs while the connect is in flight, before it answers.
  Future<void> Function()? beforeReply;
  @override
  VPNStatus build() => status;
  @override
  Future<Either<Failure, String>> connectToServer(
    ServerLocationType location,
    String tag, {
    bool skipConflictCheck = false,
  }) async {
    connects.add((location, tag));
    await beforeReply?.call();
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

/// Answers the selected_server op with [selected], or fails when null.
class _Service implements LanternService {
  _Service(this.selected);
  final String? selected;
  int selectionReads = 0;

  @override
  Future<Either<Failure, String>> helperCall(
    String op,
    Map<String, dynamic> args,
  ) async {
    if (op != 'selected_server') return const Right('{"error":"internal"}');
    selectionReads++;
    final tag = selected;
    return Right(tag == null ? '{"error":"unavailable"}' : '{"tag":"$tag"}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

ProviderContainer _selectionContainer(
  _Vpn vpn,
  _Location location, [
  _Service? service,
]) => ProviderContainer(
  overrides: [
    lanternServiceProvider.overrideWithValue(
      service ?? _Service('personal-proxy:helper-0123456789ab'),
    ),
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

Future<void> _pumpSelection(
  WidgetTester tester,
  ProviderContainer container,
) async {
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

  testWidgets('opening the tab with the VPN off reads no status and does '
      'not change a provider during build', (tester) async {
    HelpersNotifier.debugBuildEnabled = true;
    addTearDown(() => HelpersNotifier.debugBuildEnabled = null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          availableServersProvider.overrideWith(_NoServers.new),
          helpersProvider.overrideWith(
            () => _Helpers(
              const HelpersState(
                viewLoaded: true,
                view: HelpersView(
                  unlocked: true,
                  helpers: [HelperPairingView(pairingId: 'p1', online: true)],
                ),
              ),
            ),
          ),
          vpnProvider.overrideWith(() => _Vpn(VPNStatus.disconnected)),
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
    await tester.pump(personalProxyStatusInterval);
    expect(tester.takeException(), isNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PrivateServerLocationListView)),
    );
    expect(container.read(personalProxyStatusProvider), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (name, selected, fallbackEvent, want) in [
    (
      'a connect that ends on the group, with no fallback event, saves the '
          'group',
      'personal-proxies',
      false,
      'personal-proxies',
    ),
    (
      'a fallback event before the connect reply does not let the friend be '
          'saved',
      'personal-proxies',
      true,
      'personal-proxies',
    ),
    (
      'a connect that ends on the friend saves the friend',
      'personal-proxy:helper-0123456789ab',
      false,
      'personal-proxy:helper-0123456789ab',
    ),
    (
      'without an answer from radiance the requested friend is saved',
      null,
      false,
      'personal-proxy:helper-0123456789ab',
    ),
  ]) {
    testWidgets(name, (tester) async {
      await sl.reset();
      final vpn = _Vpn();
      final location = _Location();
      final service = _Service(selected);
      final container = _selectionContainer(vpn, location, service);
      addTearDown(container.dispose);
      await _pumpSelection(tester, container);
      if (fallbackEvent) {
        vpn.beforeReply = () => location.personalProxyFellBack(
          'helper-0123456789ab',
          'personal-proxies',
        );
      }
      await tester.tap(
        find.byKey(const Key('server_selection.personal_proxy.p1')),
      );
      await tester.pump();
      await tester.pump();
      expect(service.selectionReads, 1);
      expect(container.read(serverLocationProvider).serverName, want);
    });
  }

  testWidgets('selecting a friend connects by their selection tag and '
      'saves them as the location', (tester) async {
    await sl.reset();
    final vpn = _Vpn();
    final location = _Location();
    final container = _selectionContainer(vpn, location);
    addTearDown(container.dispose);
    await _pumpSelection(tester, container);
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
