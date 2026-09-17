import 'dart:async';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/lantern/lantern_service.dart';

class _FakeAutoUpdater implements AutoUpdater {
  final listeners = <UpdaterListener>[];
  final checks = <bool?>[];
  int configurations = 0;
  int? interval;
  Object? configurationError;
  Object? checkError;
  Completer<void>? pendingCheck;

  @override
  void addListener(UpdaterListener listener) => listeners.add(listener);

  @override
  void removeListener(UpdaterListener listener) => listeners.remove(listener);

  @override
  Future<void> setFeedURL(String url) async {
    configurations++;
    if (configurationError != null) throw configurationError!;
  }

  @override
  Future<void> setScheduledCheckInterval(int value) async => interval = value;

  @override
  Future<void> checkForUpdates({bool? inBackground}) async {
    checks.add(inBackground);
    if (checkError != null) throw checkError!;
    await pendingCheck?.future;
  }

  void fail() {
    for (final listener in listeners) {
      listener.onUpdaterError(null);
    }
  }

  void succeed() {
    for (final listener in listeners) {
      listener.onUpdaterUpdateNotAvailable(null);
    }
  }
}

class _FakeLanternService implements LanternService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Updater _desktopUpdater(
  _FakeAutoUpdater native, {
  Future<Map<String, dynamic>> Function()? loadFeatureFlags,
}) => Updater(
  autoUpdater: native,
  platform: TargetPlatform.macOS,
  isDebugMode: false,
  now: TestWidgetsFlutterBinding.ensureInitialized().clock.now,
  loadFeatureFlags: loadFeatureFlags,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => sl.reset());

  group('Desktop update recovery', () {
    testWidgets('checks at startup with no core service', (tester) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);

      await updater.init();
      await updater.init();
      expect(native.checks, isEmpty);
      await tester.pump(Updater.startupDelay);

      expect(native.checks, [true]);
      expect(native.interval, 3600);
      expect(native.configurations, 1);
    });

    testWidgets('checks while core initialization is still pending', (
      tester,
    ) async {
      final service = Completer<LanternService>();
      sl.registerSingletonAsync<LanternService>(() => service.future);
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);

      await updater.init();
      await tester.pump(Updater.startupDelay);

      expect(native.checks, [true]);
      service.complete(_FakeLanternService());
      await tester.pump();
    });

    testWidgets('bounds a stalled flag read and reuses the pending request', (
      tester,
    ) async {
      final flags = Completer<Map<String, dynamic>>();
      var flagReads = 0;
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(
        native,
        loadFeatureFlags: () {
          flagReads++;
          return flags.future;
        },
      );
      addTearDown(updater.dispose);

      await updater.init();
      await tester.pump(Updater.startupDelay);
      expect(native.checks, isEmpty);
      await tester.pump(Updater.featureFlagTimeout);
      expect(native.checks, [true]);

      native.fail();
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(Updater.featureFlagTimeout);
      expect(native.checks, [true, true]);
      expect(flagReads, 1);
      flags.complete({FeatureFlag.autoUpdateEnabled.key: false});
      await tester.pump();
      await updater.checkNow();
      expect(native.checks, [true, true]);
    });

    testWidgets('keeps the last flag value when a later read fails', (
      tester,
    ) async {
      var failFlags = false;
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(
        native,
        loadFeatureFlags: () async {
          if (failFlags) throw StateError('core unavailable');
          return {FeatureFlag.autoUpdateEnabled.key: false};
        },
      );
      addTearDown(updater.dispose);

      expect(await updater.canCheckForUpdates(), isFalse);
      failFlags = true;
      await updater.init();
      await tester.pump(Updater.startupDelay);
      await updater.checkNow();

      expect(native.configurations, 0);
      expect(native.checks, isEmpty);
    });

    testWidgets(
      'retries failed configuration without adding another listener',
      (tester) async {
        final native = _FakeAutoUpdater()
          ..configurationError = StateError('bridge unavailable');
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);

        await updater.init();
        await tester.pump(Updater.startupDelay);
        expect(native.configurations, 1);
        expect(native.checks, isEmpty);
        native.configurationError = null;
        await tester.pump(const Duration(minutes: 1));

        expect(native.configurations, 2);
        expect(native.listeners, [updater]);
        expect(native.checks, [true]);
      },
    );

    testWidgets(
      'keeps retrying setup hourly until native scheduling is available',
      (tester) async {
        final native = _FakeAutoUpdater()
          ..configurationError = StateError('bridge unavailable');
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);
        await updater.init();
        await tester.pump(Updater.startupDelay);
        for (final minutes in [1, 5, 15]) {
          await tester.pump(Duration(minutes: minutes));
        }
        expect(native.configurations, 4);

        await tester.pump(const Duration(hours: 1));
        expect(native.configurations, 5);
        native.configurationError = null;
        await tester.pump(const Duration(hours: 1));
        expect(native.configurations, 6);
        expect(native.checks, [true]);
        expect(native.interval, 3600);
        expect(native.listeners, [updater]);
        native.succeed();
        await tester.pump(const Duration(hours: 1));
        expect(native.configurations, 6);
        expect(native.checks, [true]);
      },
    );

    testWidgets('backs off native errors and stops after three retries', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);

      var expectedChecks = 1;
      for (final minutes in [1, 5, 15]) {
        native.fail();
        native.fail();
        await tester.pump(
          Duration(minutes: minutes) - const Duration(seconds: 1),
        );
        expect(native.checks.length, expectedChecks);
        await tester.pump(const Duration(seconds: 1));
        expect(native.checks.length, ++expectedChecks);
      }
      native.fail();
      await tester.pump(const Duration(hours: 2));
      expect(native.checks.length, 4);
      expect(native.interval, 3600);
    });

    testWidgets('a successful result resets the retry budget', (tester) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      await tester.pump(const Duration(minutes: 1));
      native.succeed();
      native.fail();
      await tester.pump(const Duration(minutes: 1));

      expect(native.checks.length, 3);
    });

    testWidgets('Sparkle no-update error does not retry a successful check', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      updater.onUpdaterCheckingForUpdate(null);
      updater.onUpdaterUpdateNotAvailable(UpdaterError('Already up to date'));
      updater.onUpdaterError(UpdaterError('Already up to date'));
      await tester.pump(const Duration(hours: 1));
      expect(native.checks, [true]);

      updater.onUpdaterError(UpdaterError('Network unavailable'));
      await tester.pump(const Duration(minutes: 1));
      expect(native.checks, [true, true]);
    });

    testWidgets(
      'a no-update result does not suppress unrelated native errors',
      (tester) async {
        final native = _FakeAutoUpdater();
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);
        await updater.init();
        await tester.pump(Updater.startupDelay);
        updater.onUpdaterUpdateNotAvailable(UpdaterError('Already up to date'));
        native.fail();
        await tester.pump(const Duration(minutes: 1));
        expect(native.checks, [true, true]);
      },
    );

    testWidgets('waits for the native result before retrying again', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      await tester.pump(const Duration(minutes: 1));
      updater.retryPendingCheck();
      await tester.pump(const Duration(minutes: 10));

      expect(native.checks, [true, true]);
    });

    testWidgets('download errors do not repeatedly offer the same update', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      updater.onUpdaterUpdateAvailable(null);
      native.fail();
      updater.retryPendingCheck();
      await tester.pump(const Duration(hours: 1));

      expect(native.checks, [true]);
      await updater.checkNow();
      native.fail();
      await tester.pump(const Duration(minutes: 1));
      expect(native.checks, [true, false, true]);
    });

    testWidgets('reconnect expedites backoff and coalesces repeated events', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      await tester.pump(const Duration(minutes: 1));
      native.fail();
      updater.retryPendingCheck();
      await tester.pump(const Duration(seconds: 30));
      updater.retryPendingCheck();
      await tester.pump(const Duration(seconds: 30));

      expect(native.checks.length, 3);
      native.succeed();
      updater.retryPendingCheck();
      await tester.pump(const Duration(minutes: 10));
      expect(native.checks.length, 3);
    });

    testWidgets(
      'reconnect cannot postpone a retry that is already due sooner',
      (tester) async {
        final native = _FakeAutoUpdater();
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);
        await updater.init();
        await tester.pump(Updater.startupDelay);
        native.fail();
        await tester.pump(const Duration(seconds: 30));
        updater.retryPendingCheck();
        await tester.pump(const Duration(seconds: 30));
        expect(native.checks, [true, true]);

        native.fail();
        await tester.pump(const Duration(minutes: 4, seconds: 30));
        updater.retryPendingCheck();
        await tester.pump(const Duration(seconds: 30));
        expect(native.checks, [true, true, true]);
      },
    );

    testWidgets('a successful result cancels a pending recovery check', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      updater.retryPendingCheck();
      updater.onUpdaterUpdateAvailable(null);
      await tester.pump(const Duration(minutes: 10));

      expect(native.checks, [true]);
    });

    testWidgets('manual checks replace startup and coalesce pending calls', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()..pendingCheck = Completer<void>();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      final check = updater.checkNow();
      await tester.pump();
      await updater.checkNow();
      await tester.pump(Updater.startupDelay);
      expect(native.checks, [false]);
      native.pendingCheck!.complete();
      await check;
    });

    testWidgets(
      'manual dispatch errors reach the caller and schedule recovery',
      (tester) async {
        final native = _FakeAutoUpdater()
          ..checkError = StateError('native check failed');
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);

        await expectLater(updater.checkNow(), throwsStateError);
        native.fail();
        native.checkError = null;
        await tester.pump(const Duration(minutes: 1));

        expect(native.checks, [false, true]);
      },
    );

    testWidgets('disposing cancels retries and removes the listener', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      updater.retryPendingCheck();
      updater.dispose();
      await tester.pump(const Duration(hours: 1));

      expect(native.listeners, isEmpty);
      expect(native.checks, [true]);
    });

    testWidgets('disposing during a flag read prevents native initialization', (
      tester,
    ) async {
      final flags = Completer<Map<String, dynamic>>();
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(
        native,
        loadFeatureFlags: () => flags.future,
      );
      await updater.init();
      await tester.pump(Updater.startupDelay);
      updater.dispose();
      flags.complete({});
      await tester.pump();

      expect(native.configurations, 0);
      expect(native.checks, isEmpty);
    });

    testWidgets('debug and unsupported platforms do not start native updates', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.iOS,
      ]) {
        final updater = Updater(
          autoUpdater: native,
          platform: platform,
          isDebugMode: platform == TargetPlatform.macOS,
        );
        await updater.init();
        await tester.pump(const Duration(minutes: 1));
        updater.dispose();
      }
      expect(native.configurations, 0);
      expect(native.checks, isEmpty);
    });
  });

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
        platform: TargetPlatform.windows,
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
        platform: TargetPlatform.windows,
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
        platform: TargetPlatform.macOS,
        quitForUpdate: () async => quitCalls++,
      );

      updater.onUpdaterBeforeQuitForUpdate(null);
      await Future<void>.delayed(Duration.zero);

      expect(quitCalls, 0);
    });
  });
}
