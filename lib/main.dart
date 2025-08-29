import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/common/app_secrets.dart';

Future<void> main() async {
  print("[Flutter] Calling main...");
  WidgetsFlutterBinding.ensureInitialized();
  print("[Flutter] WidgetsFlutterBinding initialized.");
  try {
    final flutterLogFile = await AppStorageUtils.flutterLogFile();
    print("[Flutter] Log file path: ${flutterLogFile.path}");
    initLogger(flutterLogFile.path);
    print("[Flutter] Logger initialized.");
    appLogger.debug('Starting app initialization...');
    await _configureAutoUpdate();
    print("[Flutter] Auto-update configured.");
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

  appLogger.info("Setting up Sentry...");

  await _setupSentry(
    runner: () {
      runApp(
        DevicePreview(
          enabled: false,
          builder: (context) => const ProviderScope(
            child: LanternApp(),
          ),
        ),
      );
    },
  );
}

Future<void> _configureAutoUpdate() async {
  if (kDebugMode) return;
  if (!Platform.isMacOS && !Platform.isWindows) return;
  if (AppSecrets.buildType != 'production') return;
  await autoUpdater.setFeedURL(AppUrls.appcastURL);
  await autoUpdater.checkForUpdates();
  await autoUpdater.setScheduledCheckInterval(3600);
}

Future<void> _setupSentry({required AppRunner runner}) async {
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
  tz.setLocalLocation(tz.getLocation(timeZoneName));
}

Future<void> _loadAppSecrets() async {
  try {
    await dotenv.load(fileName: "app.env");
    appLogger.debug('App secrets loaded');
  } catch (e) {
    appLogger.error("Error loading app secrets: $e");
  }
}
