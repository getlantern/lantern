import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
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
import 'package:package_info_plus/package_info_plus.dart';
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
    unawaited(_logDeviceInfo());
    await _loadAppSecrets();
    appLogger.debug('Injecting services...');
    await injectServices();
  } catch (e, st) {
    appLogger.error("Error during app initialization", e, st);
  }

  // Auto-updater is desktop-only (no-op on mobile) and already guarded
  // internally by kDebugMode and platform checks. Do not await: Sparkle's
  // setFeedURL / setScheduledCheckInterval are synchronous bridge calls that
  // can block first paint when the feed URL is slow to resolve or the
  // framework is touching keychain state. The first actual update check is
  // already deferred 45 s inside init().
  //
  // Guard the sl<Updater>() lookup: if injectServices() threw above, Updater
  // (registered at injection_container.dart:40) may not be in the registry,
  // and the synchronous lookup would throw and prevent runApp.
  try {
    if (sl.isRegistered<Updater>()) {
      unawaited(sl<Updater>().init());
    } else {
      appLogger.warning('Updater not registered, skipping init');
    }
  } catch (e, st) {
    appLogger.error('Failed to start Updater.init', e, st);
  }

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

Future<void> _logDeviceInfo() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    final Map<String, dynamic> info = {
      'appName': packageInfo.appName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };

    if (PlatformUtils.isAndroid) {
      final d = await deviceInfo.androidInfo;
      info.addAll({
        'platform': 'Android',
        'model': d.model,
        'manufacturer': d.manufacturer,
        'osVersion': d.version.release,
        'sdkInt': d.version.sdkInt,
        'device': d.device,
      });
    } else if (PlatformUtils.isIOS) {
      final d = await deviceInfo.iosInfo;
      info.addAll({
        'platform': 'iOS',
        'model': d.model,
        'name': d.name,
        'systemVersion': d.systemVersion,
      });
    } else if (PlatformUtils.isMacOS) {
      final d = await deviceInfo.macOsInfo;
      info.addAll({
        'platform': 'macOS',
        'model': d.model,
        'osRelease': d.osRelease,
        'arch': d.arch,
      });
    } else if (PlatformUtils.isWindows) {
      final d = await deviceInfo.windowsInfo;
      info.addAll({
        'platform': 'Windows',
        'majorVersion': d.majorVersion,
        'minorVersion': d.minorVersion,
        'buildNumber': d.buildNumber,
      });
    } else if (PlatformUtils.isLinux) {
      final d = await deviceInfo.linuxInfo;
      info.addAll({
        'platform': 'Linux',
        'name': d.name,
        'version': d.version,
        'id': d.id,
        'prettyName': d.prettyName,
      });
    }

    appLogger.info('Device info: $info');
  } catch (e) {
    appLogger.warning('Failed to collect device info: $e');
  }
}
