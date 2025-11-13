import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/desktop_window.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/common/app_secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDesktopWindow();

  try {
    final flutterLog = await AppStorageUtils.flutterLogFile();
    initLogger(flutterLog.path);
    appLogger.debug('Starting app initialization...');
    await _configureLocalTimeZone();
    appLogger.debug('Loading app secrets...');
    await _loadAppSecrets();
    appLogger.debug('Injecting services...');
    await injectServices();
    appLogger.debug('Loading translations...');
    await Future.microtask(Localization.loadTranslations);
  } catch (e, st) {
    appLogger.error("Error during app initialization", e, st);
  }
  final flags = await _loadFeatureFlags();

  final sentryEnabled = flags.getBool(FeatureFlag.sentry) && kReleaseMode;

  await _configureAutoUpdate(flags: flags);

  FutureOr<void> runner() {
    runApp(
      DevicePreview(
        enabled: false,
        builder: (context) => ProviderScope(
          child: const LanternApp(),
        ),
      ),
    );
  }

  if (sentryEnabled) {
    await _setupSentry(runner: runner, flags: flags);
  } else {
    runner();
  }
}

Future<Map<String, dynamic>> _loadFeatureFlags() async {
  try {
    final either = await sl<LanternCoreService>().featureFlag();
    return either.fold((_) => <String, dynamic>{}, (s) => json.decode(s));
  } catch (_) {
    return <String, dynamic>{};
  }
}

Future<void> _configureAutoUpdate({required Map<String, dynamic> flags}) async {
  if (kDebugMode) return;
  if (!Platform.isMacOS && !Platform.isWindows) return;
  final enabled = flags.getBool(FeatureFlag.autoUpdateEnabled);
  if (!enabled) return;

  await autoUpdater.setFeedURL(AppUrls.appcastURL);
  await autoUpdater.setScheduledCheckInterval(3600);

  // Add delay to avoid showing modal immediately on startup
  const firstPromptDelay = Duration(seconds: 45);
  unawaited(Future<void>.delayed(firstPromptDelay, () async {
    try {
      await autoUpdater.checkForUpdates(inBackground: true);
    } catch (e, st) {
      appLogger.error('Failed to check for auto-updates: $e', st);
    }
  }));
}

Future<void> _setupSentry(
    {required AppRunner runner, required Map<String, dynamic> flags}) async {
  await SentryFlutter.init(
    (options) {
      options.tracesSampleRate = .8;
      options.profilesSampleRate = .8;
      options.attachThreads = true;
      options.debug = false;
      options.environment = kReleaseMode ? "production" : "development";
      options.dsn = kReleaseMode ? AppSecrets.dnsConfig() : "";
      options.enableNativeCrashHandling = true;
      options.attachStacktrace = true;
      options.enableAutoNativeBreadcrumbs = true;
      options.enableNdkScopeSync = true;

      options.dist = Platform.operatingSystem;
    },
    appRunner: runner,
  );
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  if (Platform.isWindows) {
    return;
  }
  final timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
}

Future<void> _loadAppSecrets() async {
  try {
    await dotenv.load(fileName: "app.env");
    appLogger.debug('App secrets loaded');
  } catch (e) {
    appLogger.error("Error loading app secrets: $e");
  }
}
