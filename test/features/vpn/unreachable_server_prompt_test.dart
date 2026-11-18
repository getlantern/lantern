import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Right;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide ServerSelection;
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';
import 'package:loader_overlay/loader_overlay.dart';

class _Vpn extends VpnNotifier {
  final connects = <String>[];
  @override
  VPNStatus build() => VPNStatus.disconnected;
  @override
  Future<Either<Failure, String>> connectToServer(
    ServerLocationType location,
    String tag, {
    bool skipConflictCheck = false,
  }) async {
    connects.add(tag);
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
  Future<void> refreshAutoLocationIfNeeded() async {}
  @override
  // Saves and reports the request retired, so no router is needed.
  Future<bool> saveOnceConnected(
    FutureOr<void> Function() save, {
    int? stopsSince,
  }) async {
    await save();
    return false;
  }
}

Server _server(String tag, String city, {int delay = 0, int failures = 0}) =>
    Server(
      tag: tag,
      type: 'samizdat',
      isLantern: true,
      location: GeoLocation(
        country: city,
        countryCode: 'HK',
        city: city,
        latitude: 0,
        longitude: 0,
      ),
      selectionHistory: SelectionHistory(
        lastSuccessDelayMs: delay,
        consecutiveFailures: failures,
      ),
    );

late _Vpn _vpn;

Future<void> _pump(WidgetTester tester) async {
  _vpn = _Vpn();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vpnProvider.overrideWith(() => _vpn),
        serverLocationProvider.overrideWith(_Location.new),
        canSelectServerProvider.overrideWithValue(true),
        macosExtensionProvider.overrideWithValue(
          const MacOSExtensionState(SystemExtensionStatus.activated),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: GlobalLoaderOverlay(
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: Scaffold(
              body: ServerLocationListView(
                userPro: true,
                servers: AvailableServers([
                  _server('hk-bad', 'Hong Kong', failures: 3),
                  _server('sg-good', 'Singapore', delay: 80),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('a reachable server connects without a prompt', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sg-good')));
    await tester.pumpAndSettle();
    expect(find.text('unreachable_server_title'.i18n), findsNothing);
    expect(_vpn.connects, ['sg-good']);
  });

  testWidgets('an unreachable server asks first, and Cancel leaves the '
      'selection alone', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('hk-bad')));
    await tester.pumpAndSettle();
    expect(find.text('unreachable_server_title'.i18n), findsOneWidget);
    expect(_vpn.connects, isEmpty);

    await tester.tap(find.text('cancel'.i18n));
    await tester.pumpAndSettle();
    expect(find.text('unreachable_server_title'.i18n), findsNothing);
    expect(_vpn.connects, isEmpty);
  });

  testWidgets('Connect Anyway pins the unreachable server', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('hk-bad')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('unreachable_server_connect_anyway'.i18n));
    await tester.pumpAndSettle();
    expect(find.text('unreachable_server_title'.i18n), findsNothing);
    expect(_vpn.connects, ['hk-bad']);
  });
}
