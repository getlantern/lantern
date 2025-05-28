import 'dart:io';

import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern_app.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/common/app_secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initLogger();
  await _configureAutoUpdate();
  await _configureLocalTimeZone();
  await _loadAppSecrets();
  await injectServices();

  await Future.microtask(Localization.loadTranslations);

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
  if (!Platform.isMacOS) return;
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
