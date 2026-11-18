import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide ServerSelection;
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';
import 'package:lantern/features/vpn/service_repair.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

class _Lantern implements LanternService {
  _Lantern([this.result = const Right(unit)]);

  final Either<Failure, Unit> result;
  int repairs = 0;

  @override
  Future<Either<Failure, Unit>> repairService() async {
    repairs++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home) => ScreenUtilInit(
  designSize: const Size(393, 852),
  child: GlobalLoaderOverlay(
    child: MaterialApp(theme: AppTheme.appTheme(), home: home),
  ),
);

final _title = find.text('lantern_service_unavailable_title'.i18n);
final _repairFailed = find.text('lantern_service_repair_failed'.i18n);

void main() {
  setUpAll(Localization.loadTranslations);

  group('repairLanternService', () {
    late _Lantern lantern;
    bool? repaired;

    Future<void> open(WidgetTester tester) async {
      repaired = null;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    repaired = await repairLanternService(context, lantern),
                child: const Text('connect'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('connect'));
      await tester.pumpAndSettle();
      expect(_title, findsOneWidget);
    }

    testWidgets('repairs on Repair and resolves true', (tester) async {
      lantern = _Lantern();
      await open(tester);
      await tester.tap(find.text('repair'.i18n));
      await tester.pumpAndSettle();
      expect(lantern.repairs, 1);
      expect(repaired, isTrue);
      expect(_title, findsNothing);
      expect(_repairFailed, findsNothing);
    });

    testWidgets('Cancel leaves the service alone', (tester) async {
      lantern = _Lantern();
      await open(tester);
      await tester.tap(find.text('cancel'.i18n));
      await tester.pumpAndSettle();
      expect(lantern.repairs, 0);
      expect(repaired, isFalse);
    });

    testWidgets('stays quiet when the permission prompt is declined', (
      tester,
    ) async {
      lantern = _Lantern(
        Left(ServiceRepairFailure('lantern_service_repair_cancelled')),
      );
      await open(tester);
      await tester.tap(find.text('repair'.i18n));
      await tester.pumpAndSettle();
      expect(repaired, isFalse);
      expect(_repairFailed, findsNothing);
    });

    testWidgets('reports a repair that failed', (tester) async {
      lantern = _Lantern(
        Left(ServiceRepairFailure('lanternd install exited with code 1')),
      );
      await open(tester);
      await tester.tap(find.text('repair'.i18n));
      await tester.pumpAndSettle();
      expect(repaired, isFalse);
      expect(_repairFailed, findsOneWidget);
    });
  });

  testWidgets('a location connect offers the repair and retries after it', (
    tester,
  ) async {
    final lantern = _Lantern();
    final vpn = _Vpn([
      Left(ServiceUnavailableFailure('lantern_service_unavailable (stopped)')),
      const Right('ok'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnProvider.overrideWith(() => vpn),
          serverLocationProvider.overrideWith(_Location.new),
          lanternServiceProvider.overrideWithValue(lantern),
          canSelectServerProvider.overrideWithValue(true),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.activated),
          ),
        ],
        child: _app(
          Scaffold(
            body: ServerLocationListView(
              userPro: true,
              servers: AvailableServers([_server('sg-good', 'Singapore')]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('sg-good')));
    await tester.pumpAndSettle();
    expect(_title, findsOneWidget);
    expect(vpn.connects, ['sg-good']);

    await tester.tap(find.text('repair'.i18n));
    await tester.pumpAndSettle();
    expect(lantern.repairs, 1);
    expect(vpn.connects, ['sg-good', 'sg-good']);
  });
}

class _Vpn extends VpnNotifier {
  _Vpn(this.results);

  final List<Either<Failure, String>> results;
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
    return results.removeAt(0);
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

Server _server(String tag, String city) => Server(
  tag: tag,
  type: 'samizdat',
  isLantern: true,
  location: GeoLocation(
    country: city,
    countryCode: 'SG',
    city: city,
    latitude: 0,
    longitude: 0,
  ),
  selectionHistory: SelectionHistory(lastSuccessDelayMs: 80),
);
