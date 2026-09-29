import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/app_urls.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/main.dart' as app;
import 'package:path/path.dart' as p;

import 'auto_update_robot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'signed beta fixture updates under the selected failure scenario',
    (tester) async {
      expect(
        Platform.isMacOS || Platform.isWindows,
        isTrue,
        reason: 'This smoke is desktop-only',
      );
      expect(kProfileMode, isTrue, reason: 'The fixture must be a profile app');
      expect(
        AppBuildInfo.buildType,
        'beta',
        reason: 'The fixture must use the beta update channel',
      );

      final configFile = File(
        p.join(p.dirname(autoUpdateHandoffPath), 'auto-update-scenario.json'),
      );
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final scenario = config['scenario'] as String;
      expect(['baseline', 'core-unavailable'], contains(scenario));
      expect(AppBuildInfo.autoUpdateE2E, isTrue);
      final feedUrl = AppUrls.appcastFor(AppBuildInfo.buildType);
      expect(feedUrl, config['appcast_url']);

      var coreInitializationHeld = false;
      final originalInitializer = initializeLanternService;
      if (scenario != 'baseline') {
        initializeLanternService = (_) {
          coreInitializationHeld = true;
          return Completer<void>().future;
        };
      }
      addTearDown(() => initializeLanternService = originalInitializer);
      final probe = _UpdateProbe();
      autoUpdater.addListener(probe);
      addTearDown(() => autoUpdater.removeListener(probe));
      final robot = AutoUpdateRobot(tester);
      if (scenario == 'baseline') {
        await app.main();
        await robot.triggerUpdateCheck();
      } else {
        await _requireNoBypassProxy();
        // Let the production startup timer run while app initialization is pending.
        unawaited(app.main());
      }
      final offered = await probe.offered.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw StateError('Native update was not offered: ${probe.errors}');
        },
      );
      expect(offered, isTrue, reason: 'The lower fixture found no update');
      final coreReady =
          sl.isRegistered<LanternService>() && sl.isReadySync<LanternService>();
      if (scenario != 'baseline') {
        expect(coreInitializationHeld, isTrue);
        expect(coreReady, isFalse);
        await _requireNoBypassProxy();
      }
      await robot.writeNativeHandoff(
        scenario: scenario,
        feedUrl: feedUrl,
        coreInitializationHeld: coreInitializationHeld,
        coreReady: coreReady,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _requireNoBypassProxy() async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      '127.0.0.1',
      14985,
      timeout: const Duration(seconds: 1),
    );
  } on SocketException {
    return;
  } finally {
    socket?.destroy();
  }
  throw StateError(
    'The Lantern VPN bypass proxy must be stopped for this scenario',
  );
}

class _UpdateProbe with UpdaterListener {
  final offered = Completer<bool>();
  final errors = <String>[];

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? item) {}

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? item) {}

  @override
  void onUpdaterUpdateAvailable(AppcastItem? item) {
    if (!offered.isCompleted) offered.complete(true);
  }

  @override
  void onUpdaterError(UpdaterError? error) {
    errors.add('${error?.domain}: ${error?.code}');
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    if (!offered.isCompleted) offered.complete(false);
  }
}
