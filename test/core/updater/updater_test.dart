import 'dart:async';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/app_urls.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/android_sideload_updater.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/lantern/lantern_service.dart';

class _FakeAutoUpdater implements AutoUpdater {
  final listeners = <UpdaterListener>[];
  final checks = <bool?>[];
  final configurationCalls = <String>[];
  int configurations = 0;
  int? interval;
  String? feedURL;
  Object? configurationError;
  Object? checkError;
  Object? intervalError;
  Completer<void>? pendingCheck;
  Completer<void>? pendingFeed;

  @override
  void addListener(UpdaterListener listener) => listeners.add(listener);

  @override
  void removeListener(UpdaterListener listener) => listeners.remove(listener);

  @override
  Future<void> setFeedURL(String url) async {
    configurationCalls.add('feed');
    feedURL = url;
    configurations++;
    if (configurationError != null) throw configurationError!;
    await pendingFeed?.future;
  }

  @override
  Future<void> setScheduledCheckInterval(int value) async {
    configurationCalls.add('interval:$value');
    if (value > 0 && intervalError != null) throw intervalError!;
    interval = value;
  }

  @override
  Future<void> checkForUpdates({bool? inBackground}) async {
    checks.add(inBackground);
    if (checkError != null) throw checkError!;
    await pendingCheck?.future;
  }

  void fail() {
    final error = UpdaterError('Network unavailable');
    for (final listener in listeners) {
      listener.onUpdaterError(error);
      if (listener is UpdaterLifecycleListener) {
        listener.onUpdaterUpdateCycleFinished(error);
      }
    }
  }

  void succeed() {
    for (final listener in listeners) {
      listener.onUpdaterUpdateNotAvailable(null);
      if (listener is UpdaterLifecycleListener) {
        listener.onUpdaterUpdateCycleFinished(null);
      }
    }
  }
}

class _FakeAndroidUpdater extends AndroidSideloadUpdater {
  int initializations = 0;
  int manualChecks = 0;

  @override
  Future<void> init(Map<String, dynamic> flags) async => initializations++;

  @override
  bool isEnabled(Map<String, dynamic> flags, {bool logDisabled = false}) =>
      true;

  @override
  Future<AndroidSideloadUpdate?> checkForUpdate({
    bool promptIfAvailable = true,
    AndroidSideloadUpdateCheckSource source =
        AndroidSideloadUpdateCheckSource.manual,
    bool respectStartupThrottle = false,
  }) async {
    manualChecks++;
    return null;
  }
}

class _FakeLanternService implements LanternService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Updater _desktopUpdater(
  _FakeAutoUpdater native, {
  TargetPlatform platform = TargetPlatform.macOS,
  Future<Map<String, dynamic>> Function()? loadFeatureFlags,
  Future<void> Function()? quitForUpdate,
}) => Updater(
  autoUpdater: native,
  platform: platform,
  isDebugMode: false,
  now: TestWidgetsFlutterBinding.ensureInitialized().clock.now,
  loadFeatureFlags: loadFeatureFlags,
  quitForUpdate: quitForUpdate,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => sl.reset());

  group('Windows update scheduling', () {
    setUp(() {
      const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // Avoid caching PackageInfo or loading WinSparkle.dll in host-side tests.
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw MissingPluginException('Package metadata is outside this test');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    });

    testWidgets('uses one hourly timer and waits while the prompt is open', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native, platform: TargetPlatform.windows);
      addTearDown(updater.dispose);

      await updater.init();
      await tester.pump(Updater.startupDelay);
      expect(native.checks, [true]);
      expect(native.configurationCalls, ['interval:0', 'feed']);
      expect(native.interval, 0);

      native.succeed();
      await tester.pump(const Duration(minutes: 30));
      native.succeed();
      await tester.pump(const Duration(minutes: 30));
      expect(native.checks, [true, true]);

      updater.onUpdaterUpdateAvailable(null);
      await tester.pump(const Duration(hours: 24));
      await updater.checkNow();
      updater.onUpdaterUpdateCancelled();
      await updater.checkNow();
      expect(native.checks, [true, true]);

      updater.onUpdaterUpdateCycleFinished(null);
      await tester.pump(const Duration(minutes: 59));
      expect(native.checks, [true, true]);
      await tester.pump(const Duration(minutes: 1));
      expect(native.checks, [true, true, true]);
      expect(native.configurationCalls, ['interval:0', 'feed']);
    });

    testWidgets('backs off failures, ignores duplicate endings, and resets', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native, platform: TargetPlatform.windows);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);

      var checks = 1;
      for (final minutes in [1, 5, 15, 60, 60]) {
        native.fail();
        await tester.pump(const Duration(seconds: 30));
        native.fail();
        updater.onUpdaterUpdateCycleFinished(null);
        await tester.pump(
          Duration(minutes: minutes) - const Duration(seconds: 31),
        );
        expect(native.checks.length, checks);
        await tester.pump(const Duration(seconds: 1));
        expect(native.checks.length, ++checks);
      }

      native.succeed();
      await updater.checkNow();
      expect(native.checks.length, ++checks);
      native.fail();
      await tester.pump(const Duration(minutes: 1));
      expect(native.checks.length, ++checks);
      expect(native.configurations, 1);
    });

    testWidgets(
      'reconnect expedites failed checks without postponing retries',
      (tester) async {
        final native = _FakeAutoUpdater();
        final updater = _desktopUpdater(
          native,
          platform: TargetPlatform.windows,
        );
        addTearDown(updater.dispose);
        await updater.init();
        await tester.pump(Updater.startupDelay);
        native.fail();
        await tester.pump(const Duration(seconds: 30));
        updater.retryPendingCheck();
        await tester.pump(const Duration(seconds: 30));
        expect(native.checks.length, 2);

        native.fail();
        updater.retryPendingCheck();
        await tester.pump(const Duration(seconds: 30));
        updater.retryPendingCheck();
        await tester.pump(const Duration(seconds: 30));
        expect(native.checks.length, 3);

        native.succeed();
        updater.retryPendingCheck();
        await tester.pump(const Duration(minutes: 59));
        expect(native.checks.length, 3);
        await tester.pump(const Duration(minutes: 1));
        expect(native.checks.length, 4);
      },
    );

    testWidgets('native promise completion does not end the update cycle', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()..pendingCheck = Completer<void>();
      final updater = _desktopUpdater(native, platform: TargetPlatform.windows);
      addTearDown(updater.dispose);
      await updater.init();
      final check = updater.checkNow();
      await tester.pump();
      await tester.pump(const Duration(hours: 24));
      await updater.checkNow();
      updater.retryPendingCheck();
      expect(native.checks, [false]);

      native.pendingCheck!.complete();
      await check;
      await updater.checkNow();
      await tester.pump(const Duration(hours: 24));
      expect(native.checks, [false]);
      native.succeed();
      await updater.checkNow();
      expect(native.checks, [false, false]);
    });

    testWidgets(
      'rechecks a disabled feature flag hourly without native checks',
      (tester) async {
        var enabled = false;
        var flagReads = 0;
        final native = _FakeAutoUpdater();
        final updater = _desktopUpdater(
          native,
          platform: TargetPlatform.windows,
          loadFeatureFlags: () async {
            flagReads++;
            return {FeatureFlag.autoUpdateEnabled.key: enabled};
          },
        );
        addTearDown(updater.dispose);
        await updater.init();
        await tester.pump(Updater.startupDelay);
        await tester.pump(const Duration(hours: 1));
        expect(flagReads, 2);
        expect(native.configurationCalls, isEmpty);
        expect(native.checks, isEmpty);

        enabled = true;
        await tester.pump(const Duration(hours: 1));
        expect(native.checks, [true]);
        native.succeed();
        enabled = false;
        await tester.pump(const Duration(hours: 1));
        expect(flagReads, 4);
        expect(native.checks, [true]);
        expect(native.interval, 0);
        updater.dispose();
      },
    );

    testWidgets('retries a rejected manual dispatch and preserves its error', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()
        ..checkError = StateError('bridge unavailable');
      final updater = _desktopUpdater(native, platform: TargetPlatform.windows);
      addTearDown(updater.dispose);

      await expectLater(updater.checkNow(), throwsStateError);
      native.fail();
      native.checkError = null;
      await tester.pump(const Duration(minutes: 1));
      expect(native.checks, [false, true]);
      expect(native.configurations, 1);
    });

    testWidgets('disposal cancels both regular and failed-check timers', (
      tester,
    ) async {
      for (final failed in [false, true]) {
        final native = _FakeAutoUpdater();
        final updater = _desktopUpdater(
          native,
          platform: TargetPlatform.windows,
        );
        await updater.init();
        await tester.pump(Updater.startupDelay);
        if (failed) {
          native.fail();
        } else {
          native.succeed();
        }
        updater.dispose();
        updater.retryPendingCheck();
        await tester.pump(const Duration(hours: 2));
        expect(native.checks, [true]);
        expect(native.listeners, isEmpty);
      }
    });

    testWidgets('quitting cancels recovery and ignores late terminal events', (
      tester,
    ) async {
      var quitCalls = 0;
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(
        native,
        platform: TargetPlatform.windows,
        quitForUpdate: () async => quitCalls++,
      );
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      updater.onUpdaterBeforeQuitForUpdate(null);
      native.succeed();
      updater.retryPendingCheck();
      await tester.pump(const Duration(hours: 2));
      await updater.checkNow();
      expect(quitCalls, 1);
      expect(native.checks, [true]);
    });
  });

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
      expect(native.configurationCalls, [
        'interval:0',
        'feed',
        'interval:3600',
      ]);
      expect(native.feedURL, AppUrls.appcastFor(AppBuildInfo.buildType));
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

      native.succeed();
      final check = updater.checkNow();
      await tester.pump();
      await tester.pump(Updater.featureFlagTimeout);
      await check;
      expect(native.checks, [true, false]);
      expect(flagReads, 1);
      flags.complete({FeatureFlag.autoUpdateEnabled.key: false});
      await tester.pump();
      native.succeed();
      await updater.checkNow();
      expect(native.checks, [true, false]);
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
        await tester.pump(const Duration(hours: 1));
        expect(native.configurations, 6);
        expect(native.checks, [true]);
      },
    );

    testWidgets('recovers after macOS starts but enabling its schedule fails', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()
        ..intervalError = StateError('bridge unavailable');
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      expect(native.checks, isEmpty);
      expect(native.configurations, 1);
      expect(native.interval, 0);

      await tester.pump(const Duration(minutes: 1));
      expect(native.configurations, 2);
      expect(native.checks, isEmpty);

      native.intervalError = null;
      await tester.pump(const Duration(minutes: 5));
      expect(native.interval, 3600);
      expect(native.checks, [true]);
      expect(native.listeners, [updater]);
      expect(native.configurations, 3);
      expect(native.configurationCalls, [
        for (var attempt = 0; attempt < 3; attempt++) ...[
          'interval:0',
          'feed',
          'interval:3600',
        ],
      ]);

      native.succeed();
      await tester.pump(const Duration(hours: 2));
      expect(native.checks, [true]);
      await updater.checkNow();
      expect(native.checks, [true, false]);
      expect(native.configurations, 3);
    });

    testWidgets('leaves check scheduling to the native updater after setup', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      expect(native.interval, 3600);

      // Neither a missing callback nor a failed check starts a Dart retry loop.
      await tester.pump(const Duration(hours: 2));
      expect(native.checks, [true]);
      native.fail();
      updater.retryPendingCheck();
      await tester.pump(const Duration(hours: 2));
      expect(native.checks, [true]);

      native.succeed();
      updater.retryPendingCheck();
      await tester.pump(const Duration(hours: 2));
      expect(native.checks, [true]);
    });

    testWidgets('native result callbacks do not schedule additional checks', (
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
      updater.onUpdaterUpdateAvailable(null);
      updater.onUpdaterUpdateDownloaded(null);
      native.fail();
      updater.retryPendingCheck();
      await tester.pump(const Duration(hours: 2));
      expect(native.checks, [true]);

      await updater.checkNow();
      expect(native.checks, [true, false]);
    });

    testWidgets('reconnect expedites setup backoff and coalesces events', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()
        ..configurationError = StateError('bridge unavailable');
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      await tester.pump(const Duration(minutes: 1));
      expect(native.configurations, 2);

      native.configurationError = null;
      updater.retryPendingCheck();
      await tester.pump(const Duration(seconds: 30));
      updater.retryPendingCheck();
      await tester.pump(const Duration(seconds: 30));
      expect(native.configurations, 3);
      expect(native.checks, [true]);

      updater.retryPendingCheck();
      await tester.pump(const Duration(hours: 2));
      expect(native.configurations, 3);
      expect(native.checks, [true]);
    });

    testWidgets('reconnect does not postpone an earlier setup retry', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()
        ..configurationError = StateError('bridge unavailable');
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      await tester.pump(const Duration(seconds: 30));
      updater.retryPendingCheck();
      await tester.pump(const Duration(seconds: 30));
      expect(native.configurations, 2);

      await tester.pump(const Duration(minutes: 4, seconds: 30));
      native.configurationError = null;
      updater.retryPendingCheck();
      await tester.pump(const Duration(seconds: 30));
      expect(native.configurations, 3);
      expect(native.checks, [true]);
    });

    testWidgets('successful manual setup cancels pending recovery', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()
        ..configurationError = StateError('bridge unavailable');
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      updater.retryPendingCheck();
      native.configurationError = null;
      await updater.checkNow();
      await tester.pump(const Duration(hours: 2));

      expect(native.configurations, 2);
      expect(native.checks, [false]);
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
      await updater.checkNow();
      await tester.pump(const Duration(hours: 2));
      expect(native.checks, [false]);
      native.succeed();
      await updater.checkNow();
      expect(native.checks, [false, false]);
    });

    testWidgets('manual checks wait for a native scheduled cycle to finish', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.succeed();

      updater.onUpdaterCheckingForUpdate(null);
      await updater.checkNow();
      expect(native.checks, [true]);
      native.succeed();
      await updater.checkNow();
      expect(native.checks, [true, false]);
    });

    testWidgets(
      'manual checks wait for scheduled updates without a checking event',
      (tester) async {
        final native = _FakeAutoUpdater();
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);
        await updater.init();
        await tester.pump(Updater.startupDelay);
        native.succeed();

        // An update offer blocks checks even without an earlier checking event.
        updater.onUpdaterUpdateAvailable(null);
        await updater.checkNow();
        expect(native.checks, [true]);

        updater.onUpdaterUpdateCancelled();
        await updater.checkNow();
        expect(native.checks, [true]);

        updater.onUpdaterUpdateCycleFinished(null);
        await updater.checkNow();
        expect(native.checks, [true, false]);
      },
    );

    testWidgets('cancellation waits for completion and does not retry', (
      tester,
    ) async {
      final native = _FakeAutoUpdater();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      updater.onUpdaterUpdateCancelled();
      await updater.checkNow();
      expect(native.checks, [true]);
      updater.onUpdaterUpdateCycleFinished(null);
      updater.retryPendingCheck();
      await tester.pump(const Duration(minutes: 30));
      expect(native.checks, [true]);
    });

    testWidgets(
      'manual dispatch errors reach the caller without a Dart retry',
      (tester) async {
        final native = _FakeAutoUpdater()
          ..checkError = StateError('native check failed');
        final updater = _desktopUpdater(native);
        addTearDown(updater.dispose);

        await expectLater(updater.checkNow(), throwsStateError);
        native.fail();
        native.checkError = null;
        await tester.pump(const Duration(minutes: 1));

        expect(native.checks, [false]);
        await updater.checkNow();
        expect(native.checks, [false, false]);
      },
    );

    testWidgets('disposing cancels setup retries and removes the listener', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()
        ..configurationError = StateError('bridge unavailable');
      final updater = _desktopUpdater(native);
      await updater.init();
      await tester.pump(Updater.startupDelay);
      native.fail();
      updater.retryPendingCheck();
      updater.dispose();
      await tester.pump(const Duration(hours: 1));

      expect(native.listeners, isEmpty);
      expect(native.configurations, 1);
      expect(native.checks, isEmpty);
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

    testWidgets('disposing during Windows metadata lookup stops setup', (
      tester,
    ) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final packageInfo = Completer<Map<String, String>>();
      var metadataRequested = false;
      messenger.setMockMethodCallHandler(channel, (_) {
        metadataRequested = true;
        return packageInfo.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final native = _FakeAutoUpdater();
      final updater = Updater(
        autoUpdater: native,
        platform: TargetPlatform.windows,
        isDebugMode: false,
        loadFeatureFlags: () async => {},
      );
      addTearDown(updater.dispose);

      final check = updater.checkNow();
      await tester.pump();
      expect(metadataRequested, isTrue);
      updater.dispose();
      packageInfo.complete({
        'appName': 'Lantern',
        'packageName': 'org.getlantern.lantern',
        'version': '1.0.0',
        'buildNumber': '1',
      });
      await check;

      expect(native.listeners, isEmpty);
      expect(native.configurations, 0);
      expect(native.interval, isNull);
      expect(native.checks, isEmpty);
      expect(await updater.canCheckForUpdates(), isFalse);
    });

    testWidgets('disposing during feed setup prevents native scheduling', (
      tester,
    ) async {
      final native = _FakeAutoUpdater()..pendingFeed = Completer<void>();
      final updater = _desktopUpdater(native);
      addTearDown(updater.dispose);

      final check = updater.checkNow();
      await tester.pump();
      expect(native.configurations, 1);
      updater.dispose();
      native.pendingFeed!.complete();
      await check;

      expect(native.listeners, isEmpty);
      expect(native.interval, 0);
      expect(native.checks, isEmpty);
    });

    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
      testWidgets(
        'disabled desktop builds never contact the updater: $platform',
        (tester) async {
          final native = _FakeAutoUpdater();
          var flagReads = 0;
          final updater = Updater(
            autoUpdater: native,
            platform: platform,
            isDebugMode: false,
            enableDesktopUpdates: false,
            loadFeatureFlags: () async {
              flagReads++;
              return {};
            },
          );
          addTearDown(updater.dispose);

          await updater.init();
          expect(await updater.canCheckForUpdates(), isFalse);
          await updater.checkNow();
          updater.retryPendingCheck();
          await tester.pump(const Duration(hours: 1));

          expect(flagReads, 0);
          expect(native.configurations, 0);
          expect(native.listeners, isEmpty);
          expect(native.checks, isEmpty);
        },
      );
    }

    test(
      'desktop build gate does not disable Android sideload updates',
      () async {
        final android = _FakeAndroidUpdater();
        final updater = Updater(
          androidSideloadUpdater: android,
          platform: TargetPlatform.android,
          isDebugMode: false,
          enableDesktopUpdates: false,
          loadFeatureFlags: () async => {},
        );
        addTearDown(updater.dispose);

        await updater.init();
        expect(await updater.canCheckForUpdates(), isTrue);
        await updater.checkNow();

        expect(android.initializations, 1);
        expect(android.manualChecks, 1);
      },
    );

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
