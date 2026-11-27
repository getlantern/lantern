import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/pinned_server_warning.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

class _Servers extends AvailableServersNotifier {
  _Servers(this.current);
  AvailableServers current;
  int fetches = 0;

  @override
  Future<AvailableServers> build() async => current;

  @override
  Future<void> forceFetchAvailableServers() async {
    fetches++;
    state = AsyncData(current);
  }
}

Server _server({int delay = 0, int failures = 0}) => Server(
  tag: 'hk-1',
  type: 'samizdat',
  isLantern: true,
  location: GeoLocation(
    country: 'Hong Kong',
    countryCode: 'HK',
    city: 'Hong Kong',
    latitude: 0,
    longitude: 0,
  ),
  selectionHistory: SelectionHistory(
    lastSuccessDelayMs: delay,
    consecutiveFailures: failures,
  ),
);

late _Servers _servers;

Future<void> _pump(
  WidgetTester tester, {
  required Server server,
  VPNStatus status = VPNStatus.connected,
  bool pinned = true,
}) async {
  _servers = _Servers(AvailableServers([server]));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(() => _servers),
        vpnProvider.overrideWithValue(status),
        serverLocationProvider.overrideWithValue(
          pinned
              ? ServerLocation.fromServer(server: server)
              : ServerLocation(
                  serverName: '',
                  serverType: ServerLocationType.auto.name,
                ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(body: PinnedServerWarning()),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _warning = find.byKey(const Key('home.pinned_server_unreachable'));

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('warns while connected through an unreachable pinned server', (
    tester,
  ) async {
    await _pump(tester, server: _server(failures: 3));
    expect(_warning, findsOneWidget);
    expect(
      find.text(
        'pinned_server_unreachable'.i18n.fill(['Hong Kong - Hong Kong']),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stays quiet for a healthy pinned server', (tester) async {
    await _pump(tester, server: _server(delay: 90));
    expect(_warning, findsNothing);
  });

  testWidgets('stays quiet on a transient failure', (tester) async {
    await _pump(tester, server: _server(delay: 90, failures: 2));
    expect(_warning, findsNothing);
  });

  testWidgets('stays quiet when disconnected', (tester) async {
    await _pump(
      tester,
      server: _server(failures: 3),
      status: VPNStatus.disconnected,
    );
    expect(_warning, findsNothing);
    await tester.pump(pinnedServerRefreshInterval);
    expect(_servers.fetches, 0);
  });

  testWidgets('stays quiet on Smart Location', (tester) async {
    await _pump(tester, server: _server(failures: 3), pinned: false);
    expect(_warning, findsNothing);
    await tester.pump(pinnedServerRefreshInterval);
    expect(_servers.fetches, 0);
  });

  testWidgets('reloads probe results while pinned, and picks up a server '
      'that turns unreachable', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pump(tester, server: _server(delay: 90));
    expect(_warning, findsNothing);

    _servers.current = AvailableServers([_server(delay: 90, failures: 3)]);
    await tester.pump(pinnedServerRefreshInterval);
    await tester.pump();
    expect(_servers.fetches, 1);
    expect(_warning, findsOneWidget);

    _servers.current = AvailableServers([_server(delay: 90)]);
    await tester.pump(pinnedServerRefreshInterval);
    await tester.pump();
    expect(_warning, findsNothing);
  });

  testWidgets('skips reloads while the app is in the background', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pump(tester, server: _server(delay: 90));
    await tester.pump(pinnedServerRefreshInterval);
    expect(_servers.fetches, 0);
  });
}
