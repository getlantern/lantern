import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/updater/updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WinSparkle shutdown', () {
    test('quits when WinSparkle is ready to install', () async {
      final quitStarted = Completer<void>();
      final updater = Updater(
        isWindows: true,
        quitForUpdate: () async => quitStarted.complete(),
      );

      updater.onUpdaterBeforeQuitForUpdate(null);

      await quitStarted.future;
    });

    test('ignores duplicate shutdown requests', () async {
      final quitStarted = Completer<void>();
      final allowQuitToFinish = Completer<void>();
      var quitCalls = 0;
      final updater = Updater(
        isWindows: true,
        quitForUpdate: () async {
          quitCalls++;
          quitStarted.complete();
          await allowQuitToFinish.future;
        },
      );

      updater.onUpdaterBeforeQuitForUpdate(null);
      await quitStarted.future;
      updater.onUpdaterBeforeQuitForUpdate(null);
      allowQuitToFinish.complete();
      await Future<void>.delayed(Duration.zero);

      expect(quitCalls, 1);
    });

    test('leaves shutdown to Sparkle on other platforms', () async {
      var quitCalls = 0;
      final updater = Updater(
        isWindows: false,
        quitForUpdate: () async => quitCalls++,
      );

      updater.onUpdaterBeforeQuitForUpdate(null);
      await Future<void>.delayed(Duration.zero);

      expect(quitCalls, 0);
    });
  });
}
