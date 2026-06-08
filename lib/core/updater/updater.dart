import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/android_sideload_updater.dart';
import 'package:lantern/lantern/lantern_service.dart';

class Updater {
  Updater({AndroidSideloadUpdater? androidSideloadUpdater})
    : _androidSideloadUpdater =
          androidSideloadUpdater ?? AndroidSideloadUpdater();

  final AndroidSideloadUpdater _androidSideloadUpdater;

  bool _initialized = false;

  bool get _isAndroidPlatform => !kIsWeb && Platform.isAndroid;

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isAndroid);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

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
      final updater = AutoUpdater.instance;
      await updater.setFeedURL(feedUrl);
      await updater.setScheduledCheckInterval(3600);

      // Background check after startup (avoid modal immediately on launch)
      const firstPromptDelay = Duration(seconds: 45);
      unawaited(
        Future<void>.delayed(firstPromptDelay, () async {
          try {
            await updater.checkForUpdates(inBackground: true);
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
    await AutoUpdater.instance.checkForUpdates();
  }

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
