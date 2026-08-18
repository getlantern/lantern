import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/android_sideload_updater.dart';
import 'package:lantern/core/updater/winsparkle_build_version.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class Updater with UpdaterListener {
  Updater({
    AndroidSideloadUpdater? androidSideloadUpdater,
    AutoUpdater? autoUpdater,
    bool? isWindows,
    Future<void> Function()? quitForUpdate,
  }) : _androidSideloadUpdater =
           androidSideloadUpdater ?? AndroidSideloadUpdater(),
       _autoUpdater = autoUpdater,
       _isWindowsPlatform = isWindows ?? (!kIsWeb && Platform.isWindows),
       _quitForUpdate = quitForUpdate;

  final AndroidSideloadUpdater _androidSideloadUpdater;
  AutoUpdater? _autoUpdater;
  final bool _isWindowsPlatform;
  final Future<void> Function()? _quitForUpdate;

  Future<void>? _initialization;
  bool _listenerRegistered = false;
  bool _quittingForUpdate = false;

  bool get _isAndroidPlatform => !kIsWeb && Platform.isAndroid;

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isAndroid);

  // AutoUpdater opens its native event channel as soon as the singleton is
  // created. Keep that initialization off Linux and Android, where the
  // desktop plugin is not registered.
  AutoUpdater get _desktopAutoUpdater => _autoUpdater ??= AutoUpdater.instance;

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (kDebugMode || !_isSupportedPlatform) return;

    final flags = await _featureFlags();
    if (_isAndroidPlatform) {
      await _androidSideloadUpdater.init(flags);
    } else {
      await _initDesktopUpdater(flags);
    }
  }

  Future<bool> canCheckForUpdates() async {
    if (!_isSupportedPlatform) return false;
    try {
      await init();
      final flags = await _featureFlags();
      if (_isAndroidPlatform) {
        return _androidSideloadUpdater.isEnabled(flags, logDisabled: false);
      }
      return flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true);
    } catch (e, st) {
      appLogger.error('Failed to determine update-check availability', e, st);
      return false;
    }
  }

  Future<void> _initDesktopUpdater(Map<String, dynamic> flags) async {
    if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
      appLogger.info('autoUpdater disabled by feature flag');
      return;
    }

    try {
      final buildType = AppBuildInfo.buildType;
      final feedUrl = AppUrls.appcastFor(buildType);
      final autoUpdater = _desktopAutoUpdater;
      if (!_listenerRegistered) {
        autoUpdater.addListener(this);
        _listenerRegistered = true;
      }
      if (Platform.isWindows) {
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          setWinSparkleBuildVersion(packageInfo.buildNumber);
        } catch (e, st) {
          appLogger.warning('Failed to set WinSparkle build version', e, st);
        }
      }
      await autoUpdater.setFeedURL(feedUrl);
      await autoUpdater.setScheduledCheckInterval(3600);

      // Background check after startup (avoid modal immediately on launch)
      const firstPromptDelay = Duration(seconds: 45);
      unawaited(
        Future<void>.delayed(firstPromptDelay, () async {
          try {
            await autoUpdater.checkForUpdates(inBackground: true);
          } catch (e, st) {
            appLogger.error('Failed to check for auto-updates', e, st);
          }
        }),
      );

      appLogger.info(
        'autoUpdater configured. buildType=$buildType url=$feedUrl',
      );
    } catch (e, st) {
      appLogger.error('Failed to configure autoUpdater:', e, st);
    }
  }

  Future<void> checkNow() async {
    if (!_isSupportedPlatform) return;
    await init();
    final flags = await _featureFlags();

    if (_isAndroidPlatform) {
      if (!_androidSideloadUpdater.isEnabled(flags)) return;
      await _androidSideloadUpdater.checkForUpdate(
        source: AndroidSideloadUpdateCheckSource.manual,
      );
      return;
    }

    if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
      appLogger.info(
        'autoUpdater disabled by feature flag; ignoring manual check',
      );
      return;
    }
    await _desktopAutoUpdater.checkForUpdates();
  }

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    if (!_isWindowsPlatform || _quittingForUpdate) return;
    _quittingForUpdate = true;
    appLogger.info('WinSparkle is ready to install; shutting down Lantern');
    unawaited(_shutdownForWindowsUpdate());
  }

  Future<void> _shutdownForWindowsUpdate() async {
    try {
      await (_quitForUpdate ?? _quitDesktopForUpdate)();
    } catch (e, st) {
      _quittingForUpdate = false;
      appLogger.error('Failed to shut down for Windows update', e, st);
    }
  }

  Future<void> _quitDesktopForUpdate() async {
    // WinSparkle has already launched the installer when it sends this event.
    // Tear down Lantern's desktop UI so the installer can replace the binary.
    try {
      await windowManager.setPreventClose(false);
    } catch (e, st) {
      appLogger.warning('Failed to release the Lantern window', e, st);
    }
    try {
      await trayManager.destroy();
    } catch (e, st) {
      appLogger.warning('Failed to close the Lantern tray icon', e, st);
    }
    try {
      await windowManager.destroy();
    } catch (e, st) {
      appLogger.warning('Failed to close the Lantern window', e, st);
    }
    exit(0);
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterError(UpdaterError? error) {
    appLogger.warning('Desktop update check failed: $error');
  }

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {
    appLogger.info('Desktop update available');
  }

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {
    appLogger.info('Desktop update downloaded');
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {}

  Future<Map<String, dynamic>> _featureFlags() async {
    final flagResult = await sl<LanternService>().featureFlag();
    return flagResult.fold((_) => <String, dynamic>{}, (jsonStr) {
      try {
        return json.decode(jsonStr) as Map<String, dynamic>;
      } catch (e, st) {
        appLogger.warning('Failed to decode feature flags JSON', e, st);
        return <String, dynamic>{};
      }
    });
  }
}
