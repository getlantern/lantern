import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/updater/updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'constructing the updater does not initialize desktop channels',
    () async {
      const eventChannel = MethodChannel(
        'dev.leanflutter.plugins/auto_updater_event',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var channelCalls = 0;
      messenger.setMockMethodCallHandler(eventChannel, (_) async {
        channelCalls++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(eventChannel, null));

      Updater();
      await Future<void>.delayed(Duration.zero);

      expect(channelCalls, 0);
    },
  );

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
