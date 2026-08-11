import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/main.dart' as app;

import 'auto_update_robot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'lower signed beta fixture hands off the native update prompt',
    (tester) async {
      expect(
        Platform.isMacOS || Platform.isWindows,
        isTrue,
        reason: 'This smoke is desktop-only',
      );
      expect(kProfileMode, isTrue, reason: 'The fixture must be a profile app');
      expect(
        AppBuildInfo.autoUpdateE2E,
        isTrue,
        reason: 'The fixture must use the isolated staging appcast',
      );
      expect(
        AppBuildInfo.buildType,
        'beta',
        reason: 'The fixture must use the beta update channel',
      );

      await app.main();
      final robot = AutoUpdateRobot(tester);
      await robot.triggerUpdateCheck();
      await robot.writeNativeHandoff();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
