import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/desktop_window.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern_app.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone is only needed for notification scheduling (data-cap alerts),
  // not for the first frame. Run it in the background from the very start.
  unawaited(_configureLocalTimeZone());

  await Future.microtask(Localization.loadTranslations);
  await configureDesktopWindow();

  if (PlatformUtils.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  try {
    final flutterLog = await AppStorageUtils.flutterLogFile();
    initLogger(flutterLog.path);
    appLogger.debug('Starting app initialization...');
    await _loadAppSecrets();
    appLogger.debug('Injecting services...');
    await injectServices();
  } catch (e, st) {
    appLogger.error("Error during app initialization", e, st);
  }

  // Auto-updater is desktop-only (no-op on mobile) and already guarded
  // internally by kDebugMode and platform checks.
  await sl<Updater>().init();

  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      child: const LanternApp(),
    ),
  );
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb) return;

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
