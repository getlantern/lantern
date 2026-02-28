import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/desktop_window.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/common/app_secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appLogger.debug('Loading translations...');
  await Future.microtask(Localization.loadTranslations);
  await configureDesktopWindow();
  try {
    if (PlatformUtils.isMobile) {
      /// Locking orientation to portrait only for mobile devices
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    final flutterLog = await AppStorageUtils.flutterLogFile();
    initLogger(flutterLog.path);
    appLogger.debug('Starting app initialization...');
    await _configureLocalTimeZone();
    appLogger.debug('Loading app secrets...');
    await _loadAppSecrets();
    appLogger.debug('Injecting services...');
    await injectServices();
  } catch (e, st) {
    appLogger.error("Error during app initialization", e, st);
  }
  final flags = await _loadFeatureFlags();
  final sentryEnabled = flags.getBool(FeatureFlag.sentry) && kReleaseMode;
  await sl<Updater>().init(flags: flags);

  FutureOr<void> runner() {
    runApp(
      ProviderScope(
        retry: (retryCount, error) => null,
        child: const LanternApp(),
      ),
    );
  }

  if (sentryEnabled) {
    await _setupSentry(runner: runner);
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
      options.dist = Platform.operatingSystem;
    },
    appRunner: runner,
  );
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb) {
    return;
  }

  tz.initializeTimeZones();

  try {
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
  } catch (e) {
    appLogger.warning(
      'Failed to configure local timezone, falling back to UTC: $e',
    );
    tz.setLocalLocation(tz.UTC);
  }
}

Future<void> _loadAppSecrets() async {
  try {
    await dotenv.load(fileName: "app.env");
    appLogger.debug('App secrets loaded');
  } catch (e) {
    appLogger.error("Error loading app secrets: $e");
  }
}
